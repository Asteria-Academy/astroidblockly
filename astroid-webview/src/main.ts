// src/main.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';
import { ContinuousToolbox, ContinuousFlyout, registerContinuousToolbox } from '@blockly/continuous-toolbox';

import { getAstroidToolbox } from './toolbox';
import { getAstroidTheme } from './visual/theme';
import { runCommandsOnRobot } from './command_runner';
import { initializeAstroidEditor } from './core';
import { Simulator } from './simulator';
import { SimulatorSequencer } from './simulator_sequencer';

declare global {
  interface Window {
    astroidAppChannel: (message: string) => void;

    getProjectList: () => string;
    deleteProject: (projectId: string) => void;
    renameProject: (projectId: string, newName: string) => void;
    setSequencerState: (state: 'running' | 'idle') => void;
    updateSequencerState: (state: 'running' | 'idle') => void;
    generateCodeForExecution: () => string;
    toggleDebugView: () => void;
    setViewMode?: (mode: 'blocks' | 'chat') => void;
  }
}

interface Project {
  id: string;
  name: string;
  last_modified: number;
  workspace_json: any;
  thumbnail_data?: string | null;
}

const INITIAL_WORKSPACE_JSON = {
  "blocks": {
    "languageVersion": 0, "blocks": [
      {
        "type": "program_start", "id": "start_block", "x": 200, "y": 100, "deletable": false, "movable": false,
        "next": { "block": { "type": "motor_stop" } }
      }
    ]
  }
};

initializeAstroidEditor();

const blocklyDiv = document.getElementById('blockly-div');
const playButton = document.getElementById('play-button');
const btStatusButton = document.getElementById('bt-status-button');
const saveIndicator = document.getElementById('save-indicator');
const saveIndicatorLabel = document.getElementById('save-indicator-label');
const projectNameInput = document.getElementById('project-name-input') as HTMLInputElement | null;
const backButton = document.getElementById('back-button') as HTMLButtonElement | null;
const viewToggleBlocks = document.getElementById('view-toggle-blocks') as HTMLButtonElement | null;
const viewToggleChat = document.getElementById('view-toggle-chat') as HTMLButtonElement | null;
const floatingToolbar = document.getElementById('floating-toolbar');
const toolbarGrip = document.getElementById('toolbar-grip');
const toolbarCollapse = document.getElementById('toolbar-collapse');
const resetButton = document.getElementById('reset-button') as HTMLButtonElement | null;
const undoButton = document.getElementById('undo-button') as HTMLButtonElement | null;
const redoButton = document.getElementById('redo-button') as HTMLButtonElement | null;
const viewerToggle = document.getElementById('viewer-toggle') as HTMLButtonElement | null;
const recenterButton = document.getElementById('recenter-button') as HTMLButtonElement | null;
const trashZone = document.getElementById('trash-zone');
const simulatorHeader = document.getElementById('simulator-header');
const simulatorCloseButton = document.getElementById('simulator-close');
const simulatorResizeHandle = document.getElementById('simulator-resize-handle');
const simulatorContainerElement = document.getElementById('simulator-container');
const fullscreenButton = document.getElementById('fullscreen-button');
const fsEnterIcon = fullscreenButton?.querySelector('.icon-fullscreen-enter') as SVGElement | null;
const fsExitIcon = fullscreenButton?.querySelector('.icon-fullscreen-exit') as SVGElement | null;

let primaryWorkspace: Blockly.WorkspaceSvg;
let currentProjectId: string | null = null;
let saveTimeout: number | null = null;
let currentProjectName = '';

type SaveState = 'saved' | 'unsaved' | 'saving';
let currentSaveState: SaveState = 'saved';
let isViewerVisible = true;
let isBlockDragActive = false;
let blockDragTargetId: string | null = null;
const lastPointerPosition = { x: 0, y: 0 };
let suppressSaveIndicator = false;

function normalizeBound(value: string | undefined): string {
  if (!value || value === 'auto') {
    return '';
  }
  return value;
}

function storeSimulatorBounds(container: HTMLElement) {
  container.dataset.prevLeft = normalizeBound(container.style.left);
  container.dataset.prevTop = normalizeBound(container.style.top);
  container.dataset.prevRight = normalizeBound(container.style.right);
  container.dataset.prevBottom = normalizeBound(container.style.bottom);
  container.dataset.prevWidth = normalizeBound(container.style.width);
  container.dataset.prevHeight = normalizeBound(container.style.height);
}

function restoreSimulatorBounds(container: HTMLElement) {
  const { prevLeft, prevTop, prevRight, prevBottom, prevWidth, prevHeight } = container.dataset;
  container.style.left = normalizeBound(prevLeft);
  container.style.top = normalizeBound(prevTop);
  container.style.right = normalizeBound(prevRight);
  container.style.bottom = normalizeBound(prevBottom);
  container.style.width = normalizeBound(prevWidth);
  container.style.height = normalizeBound(prevHeight);
}

function clearStoredBounds(container: HTMLElement) {
  delete container.dataset.prevLeft;
  delete container.dataset.prevTop;
  delete container.dataset.prevRight;
  delete container.dataset.prevBottom;
  delete container.dataset.prevWidth;
  delete container.dataset.prevHeight;
}

function hasStoredBounds(container: HTMLElement): boolean {
  const { prevLeft, prevTop, prevRight, prevBottom, prevWidth, prevHeight } = container.dataset;
  return Boolean(prevLeft || prevTop || prevRight || prevBottom || prevWidth || prevHeight);
}

function setFullscreenIconState(isFullscreen: boolean) {
  if (!fsEnterIcon || !fsExitIcon) {
    return;
  }
  fsEnterIcon.style.display = isFullscreen ? 'none' : 'block';
  fsExitIcon.style.display = isFullscreen ? 'block' : 'none';
}

function updateViewerToggleUI(visible: boolean) {
  viewerToggle?.classList.toggle('active', visible);
  viewerToggle?.setAttribute('aria-pressed', visible ? 'true' : 'false');
  viewerToggle?.setAttribute('aria-label', visible ? 'Hide 3D viewer' : 'Show 3D viewer');
  viewerToggle?.setAttribute('title', visible ? 'Hide 3D viewer' : 'Show 3D viewer');
  simulatorCloseButton?.setAttribute('aria-expanded', visible ? 'true' : 'false');
  simulatorCloseButton?.setAttribute('aria-label', visible ? 'Collapse viewer' : 'Expand viewer');
}

updateViewerToggleUI(isViewerVisible);
setFullscreenIconState(false);

function getProjectsData() {
  const data = localStorage.getItem('astroid_projects');
  if (!data) return { last_opened_id: null, projects: [] };
  try {
    return JSON.parse(data);
  } catch (e) {
    return { last_opened_id: null, projects: [] };
  }
}

function saveProjectsData(data: any) {
  localStorage.setItem('astroid_projects', JSON.stringify(data));
}

document.addEventListener('pointermove', (event: PointerEvent) => {
  lastPointerPosition.x = event.clientX;
  lastPointerPosition.y = event.clientY;
  updateTrashZoneHighlight();
});

backButton?.addEventListener('click', () => {
  if (window.astroidAppChannel) {
    window.astroidAppChannel('{"event":"navigate_home"}');
  } else {
    window.history.back();
  }
});

projectNameInput?.addEventListener('keydown', (event: KeyboardEvent) => {
  if (event.key === 'Enter') {
    event.preventDefault();
    projectNameInput.blur();
  }
});

projectNameInput?.addEventListener('blur', () => {
  if (!projectNameInput) return;
  renameActiveProject(projectNameInput.value);
});

viewToggleBlocks?.addEventListener('click', () => {
  setViewToggle('blocks');
});

viewToggleChat?.addEventListener('click', () => {
  setViewToggle('chat');
  if (window.astroidAppChannel) {
    window.astroidAppChannel('{"event":"open_chat_ai"}');
  }
});

setViewToggle('blocks');
window.setViewMode = (mode: 'blocks' | 'chat') => setViewToggle(mode);

toolbarCollapse?.addEventListener('click', () => {
  if (!floatingToolbar) return;
  floatingToolbar.classList.toggle('collapsed');
  toolbarCollapse.setAttribute('aria-expanded', floatingToolbar.classList.contains('collapsed') ? 'false' : 'true');
});
toolbarCollapse?.setAttribute('aria-expanded', floatingToolbar?.classList.contains('collapsed') ? 'false' : 'true');

makeDraggable(floatingToolbar, toolbarGrip);
makeDraggable(simulatorContainerElement, simulatorHeader, {
  shouldIgnore: () => simulatorContainerElement?.classList.contains('fullscreen') ?? false
});
makeResizable(simulatorContainerElement, simulatorResizeHandle);

viewerToggle?.addEventListener('click', () => {
  toggleViewerVisibility(!isViewerVisible);
});

simulatorCloseButton?.addEventListener('click', () => {
  toggleViewerVisibility(false);
});


function setSaveState(state: SaveState) {
  if (!saveIndicator || !saveIndicatorLabel) {
    return;
  }

  if (currentSaveState === state) {
    return;
  }

  saveIndicator.classList.remove('saved', 'unsaved', 'saving');
  saveIndicator.classList.add(state);

  switch (state) {
    case 'unsaved':
      saveIndicatorLabel.textContent = '\u25CF Unsaved';
      break;
    case 'saving':
      saveIndicatorLabel.textContent = '\u21BB Saving...';
      break;
    default:
      saveIndicatorLabel.textContent = '\u2713 Saved';
      break;
  }

  currentSaveState = state;
}

function updateProjectNameField(name: string) {
  if (projectNameInput) {
    projectNameInput.value = name;
  }
}

function applyActiveProject(project: Project) {
  currentProjectId = project.id;
  currentProjectName = project.name;
  updateProjectNameField(project.name);
  setSaveState('saved');
}

function renameActiveProject(newName: string) {
  if (!currentProjectId) {
    return;
  }

  const trimmed = newName.trim();
  if (!trimmed || trimmed === currentProjectName) {
    updateProjectNameField(currentProjectName);
    return;
  }

  const data = getProjectsData();
  const projectIndex = data.projects.findIndex((p: Project) => p.id === currentProjectId);
  if (projectIndex === -1) {
    console.warn('Unable to rename project. Project not found.');
    return;
  }

  const preserveState = currentSaveState !== 'saved';
  if (!preserveState) {
    setSaveState('saving');
  }

  data.projects[projectIndex].name = trimmed;
  data.projects[projectIndex].last_modified = Date.now();
  data.last_opened_id = currentProjectId;
  saveProjectsData(data);

  currentProjectName = trimmed;
  updateProjectNameField(trimmed);
  if (!preserveState) {
    setSaveState('saved');
  }
}

function setViewToggle(mode: 'blocks' | 'chat') {
  const isBlocks = mode === 'blocks';
  viewToggleBlocks?.classList.toggle('active', isBlocks);
  viewToggleBlocks?.setAttribute('aria-selected', isBlocks ? 'true' : 'false');
  viewToggleChat?.classList.toggle('active', !isBlocks);
  viewToggleChat?.setAttribute('aria-selected', !isBlocks ? 'true' : 'false');
}

function updateTrashZoneHighlight() {
  if (!trashZone || !isBlockDragActive) {
    return;
  }
  const bounds = trashZone.getBoundingClientRect();
  const isInside = lastPointerPosition.x >= bounds.left &&
    lastPointerPosition.x <= bounds.right &&
    lastPointerPosition.y >= bounds.top &&
    lastPointerPosition.y <= bounds.bottom;
  trashZone.classList.toggle('armed', isInside);
}

function toggleViewerVisibility(visible: boolean) {
  const simulatorContainer = simulatorContainerElement;
  if (!simulatorContainer || visible === isViewerVisible) {
    return;
  }

  if (visible) {
    simulatorContainer.classList.remove('hidden');
    setFullscreenIconState(false);
    if (!simulatorContainer.style.left && !simulatorContainer.style.right) {
      simulatorContainer.style.right = '';
      simulatorContainer.style.bottom = '';
    }
  } else {
    if (simulatorContainer.classList.contains('fullscreen')) {
      simulatorContainer.classList.remove('fullscreen');
      setFullscreenIconState(false);
      if (hasStoredBounds(simulatorContainer)) {
        restoreSimulatorBounds(simulatorContainer);
        clearStoredBounds(simulatorContainer);
      }
    }
    simulatorContainer.classList.add('hidden');
  }

  updateViewerToggleUI(visible);
  isViewerVisible = visible;
}

type DraggableOptions = {
  shouldIgnore?: () => boolean;
};

function makeDraggable(element: HTMLElement | null, handle: HTMLElement | null, options: DraggableOptions = {}) {
  if (!element || !handle) {
    return;
  }

  const MIN_LEFT = 8;
  const BOTTOM_PADDING = 12;
  const GLOBAL_MIN_TOP = 64;

  let startX = 0;
  let startY = 0;
  let startLeft = 0;
  let startTop = 0;
  let parentRect: DOMRect | null = null;
  let parentWidth = window.innerWidth;
  let parentHeight = window.innerHeight;
  let minTop = 64;

  const onPointerMove = (event: PointerEvent) => {
    const deltaX = event.clientX - startX;
    const deltaY = event.clientY - startY;

    const proposedLeft = startLeft + deltaX;
    const proposedTop = startTop + deltaY;

    const maxLeft = Math.max(MIN_LEFT, parentWidth - element.offsetWidth - MIN_LEFT);
    const maxTop = Math.max(minTop, parentHeight - element.offsetHeight - BOTTOM_PADDING);

    const clampedLeft = Math.min(Math.max(MIN_LEFT, proposedLeft), maxLeft);
    const clampedTop = Math.min(Math.max(minTop, proposedTop), maxTop);

    element.style.left = `${clampedLeft}px`;
    element.style.top = `${clampedTop}px`;
  };

  const onPointerUp = (event: PointerEvent) => {
    handle.releasePointerCapture(event.pointerId);
    document.removeEventListener('pointermove', onPointerMove);
    document.removeEventListener('pointerup', onPointerUp);
    element.classList.remove('dragging');
  };

  handle.addEventListener('pointerdown', (event: PointerEvent) => {
    if (options.shouldIgnore?.()) {
      return;
    }

    const target = event.target as HTMLElement | null;
    if (target && target.closest('button, a, input, textarea, select')) {
      return;
    }

    event.preventDefault();
    const rect = element.getBoundingClientRect();
    const parentElement = element.offsetParent as HTMLElement | null;
    parentRect = parentElement?.getBoundingClientRect() ?? null;
    parentWidth = parentElement ? parentElement.clientWidth : window.innerWidth;
    parentHeight = parentElement ? parentElement.clientHeight : window.innerHeight;

    const relativeLeft = rect.left - (parentRect?.left ?? 0);
    const relativeTop = rect.top - (parentRect?.top ?? 0);

    element.style.left = `${relativeLeft}px`;
    element.style.top = `${relativeTop}px`;
    element.style.right = 'auto';
    element.style.bottom = 'auto';

    startX = event.clientX;
    startY = event.clientY;
    startLeft = relativeLeft;
    startTop = relativeTop;

    minTop = Math.max(MIN_LEFT, GLOBAL_MIN_TOP - (parentRect?.top ?? 0));
    parentWidth = Math.max(parentWidth, element.offsetWidth + MIN_LEFT * 2);
    parentHeight = Math.max(parentHeight, element.offsetHeight + minTop + BOTTOM_PADDING);

    element.classList.add('dragging');
    handle.setPointerCapture(event.pointerId);
    document.addEventListener('pointermove', onPointerMove);
    document.addEventListener('pointerup', onPointerUp, { once: false });
  });
}

function makeResizable(element: HTMLElement | null, handle: HTMLElement | null) {
  if (!element || !handle) {
    return;
  }

  handle.addEventListener('pointerdown', (event: PointerEvent) => {
    if (element.classList.contains('fullscreen')) {
      return;
    }

    event.preventDefault();
    const startRect = element.getBoundingClientRect();
    const startX = event.clientX;
    const startY = event.clientY;

    const onPointerMove = (moveEvent: PointerEvent) => {
      const deltaX = moveEvent.clientX - startX;
      const deltaY = moveEvent.clientY - startY;

      const minWidth = 260;
      const minHeight = 180;

      let newWidth = Math.max(minWidth, startRect.width + deltaX);
      let newHeight = Math.max(minHeight, startRect.height + deltaY);

      newWidth = Math.min(newWidth, window.innerWidth - startRect.left - 16);
      newHeight = Math.min(newHeight, window.innerHeight - startRect.top - 16);

      element.style.width = `${newWidth}px`;
      element.style.height = `${newHeight}px`;
    };

    const onPointerUp = (upEvent: PointerEvent) => {
      document.removeEventListener('pointermove', onPointerMove);
      document.removeEventListener('pointerup', onPointerUp);
      handle.releasePointerCapture(upEvent.pointerId);
    };

    handle.setPointerCapture(event.pointerId);
    document.addEventListener('pointermove', onPointerMove);
    document.addEventListener('pointerup', onPointerUp);
  });
}



async function generateWorkspaceThumbnail(): Promise<string | null> {
  if (!primaryWorkspace) {
    return null;
  }

  const parentSvg = primaryWorkspace.getParentSvg();
  if (!parentSvg) {
    return null;
  }

  const padding = 48;
  const scale = primaryWorkspace.getScale();
  const minWidth = 320;
  const minHeight = 220;

  const bbox = primaryWorkspace.getBlocksBoundingBox();
  const hasBlocks = Boolean(bbox) && isFinite(bbox!.right - bbox!.left) && isFinite(bbox!.bottom - bbox!.top) &&
    (bbox!.right - bbox!.left) > 0 && (bbox!.bottom - bbox!.top) > 0;

  const blockLeft = hasBlocks ? bbox!.left : 0;
  const blockTop = hasBlocks ? bbox!.top : 0;
  const blockWidth = hasBlocks ? (bbox!.right - bbox!.left) : 180;
  const blockHeight = hasBlocks ? (bbox!.bottom - bbox!.top) : 120;

  const viewWidth = blockWidth + padding * 2;
  const viewHeight = blockHeight + padding * 2;

  const exportWidth = Math.max(viewWidth * scale, minWidth);
  const exportHeight = Math.max(viewHeight * scale, minHeight);

  const xmlNs = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(xmlNs, 'svg');
  svg.setAttribute('xmlns', xmlNs);
  svg.setAttribute('viewBox', `0 0 ${viewWidth} ${viewHeight}`);
  svg.setAttribute('width', `${exportWidth}`);
  svg.setAttribute('height', `${exportHeight}`);
  svg.setAttribute('shape-rendering', 'geometricPrecision');

  const defs = parentSvg.querySelector('defs');
  if (defs) {
    svg.appendChild(defs.cloneNode(true));
  }

  const background = document.createElementNS(xmlNs, 'rect');
  background.setAttribute('x', '0');
  background.setAttribute('y', '0');
  background.setAttribute('width', `${viewWidth}`);
  background.setAttribute('height', `${viewHeight}`);
  background.setAttribute('fill', '#0B1433');
  svg.appendChild(background);

  const translateX = padding - blockLeft;
  const translateY = padding - blockTop;
  const exportTransform = `translate(${translateX}, ${translateY}) scale(${scale})`;

  const blockCanvas = primaryWorkspace.getCanvas().cloneNode(true) as SVGGElement;
  blockCanvas.setAttribute('transform', exportTransform);
  svg.appendChild(blockCanvas);

  const bubbleCanvas = primaryWorkspace.getBubbleCanvas().cloneNode(true) as SVGGElement;
  bubbleCanvas.setAttribute('transform', exportTransform);
  svg.appendChild(bubbleCanvas);

  const serializer = new XMLSerializer();
  const svgMarkup = serializer.serializeToString(svg);
  const blob = new Blob([svgMarkup], { type: 'image/svg+xml;charset=utf-8' });
  const objectUrl = URL.createObjectURL(blob);

  try {
    const image = await new Promise<HTMLImageElement>((resolve, reject) => {
      const img = new Image();
      img.onload = () => resolve(img);
      img.onerror = reject;
      img.src = objectUrl;
    });

    const dpr = window.devicePixelRatio || 1;
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(exportWidth * dpr);
    canvas.height = Math.round(exportHeight * dpr);

    const ctx = canvas.getContext('2d');
    if (!ctx) {
      return null;
    }

    ctx.scale(dpr, dpr);
    ctx.fillStyle = '#0B1433';
    ctx.fillRect(0, 0, exportWidth, exportHeight);
    ctx.drawImage(image, 0, 0, exportWidth, exportHeight);

    return canvas.toDataURL('image/png');
  } catch (error) {
    console.warn('Thumbnail render failed', error);
    return null;
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

(window as any).getProjectList = function () {
  const data = getProjectsData();
  const projectList = data.projects.map((p: Project) => ({
    id: p.id,
    name: p.name,
    last_modified: p.last_modified,
    thumbnail_data: p.thumbnail_data ?? null
  }));
  return JSON.stringify(projectList);
};

(window as any).deleteProject = function (projectId: string) {
  let data = getProjectsData();
  data.projects = data.projects.filter((p: Project) => p.id !== projectId);
  if (data.last_opened_id === projectId) {
    data.last_opened_id = null;
  }
  saveProjectsData(data);
};

(window as any).renameProject = function (projectId: string, newName: string) {
  if (!newName || newName.trim().length === 0) {
    console.error("New project name cannot be empty.");
    return;
  }

  let data = getProjectsData();
  const projectIndex = data.projects.findIndex((p: Project) => p.id === projectId);

  if (projectIndex !== -1) {
    const trimmed = newName.trim();
    data.projects[projectIndex].name = trimmed;
    data.projects[projectIndex].last_modified = Date.now();
    saveProjectsData(data);
    if (projectId === currentProjectId) {
      currentProjectName = trimmed;
      updateProjectNameField(trimmed);
    }
    console.log(`Project ${projectId} renamed to ${trimmed}`);
  } else {
    console.error(`Could not find project with ID ${projectId} to rename.`);
  }
};

(window as any).generateCodeForExecution = (): string => {
  if (!primaryWorkspace) return '';
  javascriptGenerator.init(primaryWorkspace);

  const topBlocks = primaryWorkspace.getTopBlocks(true);
  const startBlock = topBlocks.find(block => block.type === 'program_start');
  if (startBlock) {
    const firstCommandBlock = startBlock.getNextBlock();
    if (firstCommandBlock) {
      const code = javascriptGenerator.blockToCode(firstCommandBlock) as string;
      const commands = code.split(';').filter(c => c.trim() !== '');
      const commandArray = commands.map(c => JSON.parse(c));
      return JSON.stringify(commandArray);
    }
  }
  return '[]';
};

function initializeWorkspace() {
  if (!blocklyDiv || !playButton || !btStatusButton) {
    throw new Error('Required DOM elements not found!');
  }

  const simulatorContainer = simulatorContainerElement;
  const modeCheckbox = document.getElementById('mode-checkbox') as HTMLInputElement;
  const simLabel = document.getElementById('mode-label-sim');
  const runLabel = document.getElementById('mode-label-run');

  let simulator: Simulator | null = null;
  let sequencer: SimulatorSequencer | null = null;
  let isSimulateMode = true;

  if (simulatorContainer) {
    simulator = new Simulator(simulatorContainer);
    simulator.loadRobotModel('Asteria-DashMinimal.glb');
    sequencer = new SimulatorSequencer(simulator);
    simulator.sequencerVirtualPosition = sequencer.virtualPosition;
  }

  let debugVisible = false;
  (window as any).toggleDebugView = () => {
    debugVisible = !debugVisible;
    simulator?.toggleCollisionHelpers(debugVisible);
    console.log(`Debug collision helpers are now ${debugVisible ? 'ON' : 'OFF'}`);
  };

  registerContinuousToolbox();

  const workspaceConfig: Blockly.BlocklyOptions = {
    theme: getAstroidTheme(),
    toolbox: getAstroidToolbox(),
    renderer: "zelos",
    toolboxPosition: 'start',
    trashcan: false,
    zoom: { controls: false, wheel: true, startScale: 0.5, maxScale: 1.25, minScale: 0.4, scaleSpeed: 1.05 },
    grid: { spacing: 20, length: 3, colour: '#444', snap: true },
    move: { scrollbars: true, drag: true, wheel: true },
    plugins: {
      toolbox: ContinuousToolbox,
      flyoutsVerticalToolbox: ContinuousFlyout,
    },
  };

  primaryWorkspace = Blockly.inject(blocklyDiv, workspaceConfig);

  const urlParams = new URLSearchParams(window.location.search);
  const action = urlParams.get('action');
  const projectId = urlParams.get('id');
  const stopButtonSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M6 6h12v12H6z"></path></svg>`;
  const playButtonSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"></path></svg>`;

  let sequencerRunning = false;

  updateViewerToggleUI(isViewerVisible);
  simulatorHeader?.classList.remove('dragging');

  window.setSequencerState = (state: 'running' | 'idle') => {
    if (state === 'running') {
      playButton.innerHTML = stopButtonSvg;
      sequencerRunning = true;
    } else {
      playButton.innerHTML = playButtonSvg;
      sequencerRunning = false;
    }
  };

  window.updateSequencerState = (state: 'running' | 'idle') => {
    window.setSequencerState(state);
  };

  let data = getProjectsData();

  resetButton?.addEventListener('click', () => {
    if (!primaryWorkspace) return;
    const shouldReset = window.confirm('Reset workspace to starter blocks? This action cannot be undone.');
    if (!shouldReset) {
      return;
    }
    Blockly.serialization.workspaces.load(INITIAL_WORKSPACE_JSON, primaryWorkspace);
    setSaveState('unsaved');
  });

  undoButton?.addEventListener('click', () => {
    primaryWorkspace.undo(false);
  });

  redoButton?.addEventListener('click', () => {
    primaryWorkspace.undo(true);
  });

  recenterButton?.addEventListener('click', () => {
    primaryWorkspace.scrollCenter();
  });

  let projectLoaded = false;

  if (action === 'open' && projectId) {
    const projectToLoad = data.projects.find((p: Project) => p.id === projectId);
    if (projectToLoad) {
      console.log(`Opening specific project: ${projectToLoad.name}`);
      suppressSaveIndicator = true;
      try {
        Blockly.serialization.workspaces.load(projectToLoad.workspace_json, primaryWorkspace);
      } finally {
        suppressSaveIndicator = false;
      }
      applyActiveProject(projectToLoad);
      data.last_opened_id = projectId;
      projectLoaded = true;
    } else {
      console.error(`Project with ID ${projectId} not found. Defaulting to last session.`);
    }
  } else if (action === 'new_project') {
    console.log("Action: Creating a new project.");
    createNewProject(data);
    projectLoaded = true;
  }

  if (!projectLoaded) {
    const lastProject = data.projects.find((p: Project) => p.id === data.last_opened_id);
    if (lastProject) {
      console.log(`Defaulting to last opened project: ${lastProject.name}`);
      suppressSaveIndicator = true;
      try {
        Blockly.serialization.workspaces.load(lastProject.workspace_json, primaryWorkspace);
      } finally {
        suppressSaveIndicator = false;
      }
      applyActiveProject(lastProject);
    } else {
      if (data.projects.length > 0) {
        data.projects.sort((a: Project, b: Project) => b.last_modified - a.last_modified);
        const mostRecentProject = data.projects[0];
        console.log(`No last opened project found. Loading most recent: ${mostRecentProject.name}`);
        suppressSaveIndicator = true;
        try {
          Blockly.serialization.workspaces.load(mostRecentProject.workspace_json, primaryWorkspace);
        } finally {
          suppressSaveIndicator = false;
        }
        applyActiveProject(mostRecentProject);
        data.last_opened_id = mostRecentProject.id;
      } else {
        console.log("No projects found. Creating a new one.");
        createNewProject(data);
      }
    }
  }

  saveProjectsData(data);

  primaryWorkspace.addChangeListener((event: Blockly.Events.Abstract) => {
    if (event.type === Blockly.Events.BLOCK_DRAG) {
      const dragEvent = event as Blockly.Events.BlockDrag;
      if (dragEvent.isStart) {
        isBlockDragActive = true;
        blockDragTargetId = dragEvent.blockId ?? null;
        trashZone?.classList.add('visible');
        updateTrashZoneHighlight();
      } else {
        const shouldDelete = trashZone?.classList.contains('armed');
        trashZone?.classList.remove('visible', 'armed');
        if (shouldDelete && blockDragTargetId) {
          const block = primaryWorkspace.getBlockById(blockDragTargetId);
          block?.dispose(true);
        }
        isBlockDragActive = false;
        blockDragTargetId = null;
      }
    }

    if (event.isUiEvent || primaryWorkspace.isDragging() || !currentProjectId || suppressSaveIndicator) {
      return;
    }

    setSaveState('unsaved');

    if (saveTimeout !== null) {
      clearTimeout(saveTimeout);
    }

    saveTimeout = window.setTimeout(async () => {
      console.log("Debounced save triggered.");
      setSaveState('saving');
      const workspaceJson = Blockly.serialization.workspaces.save(primaryWorkspace);
      let currentData = getProjectsData();
      const projectIndex = currentData.projects.findIndex((p: Project) => p.id === currentProjectId);

      if (projectIndex !== -1) {
        currentData.projects[projectIndex].workspace_json = workspaceJson;
        currentData.projects[projectIndex].last_modified = Date.now();
        try {
          const thumbnailData = await generateWorkspaceThumbnail();
          if (thumbnailData) {
            currentData.projects[projectIndex].thumbnail_data = thumbnailData;
          }
        } catch (error) {
          console.warn('Failed to capture workspace thumbnail', error);
        }
        currentData.last_opened_id = currentProjectId;
        saveProjectsData(currentData);
        console.log("Project auto-saved.");
        setSaveState('saved');
      } else {
        setSaveState('unsaved');
      }
    }, 1000);
  });

  playButton.addEventListener('click', () => {
    if (sequencerRunning) {
      // --- Stop Logic ---
      if (isSimulateMode) {
        sequencer?.stopSequence();
        window.setSequencerState('idle');
      } else {
        if (window.astroidAppChannel) {
          window.astroidAppChannel('{"event":"stop_code"}');
        }
      }
    } else {
      const commandJsonString = window.generateCodeForExecution();

      if (isSimulateMode) {
        console.log("Running in Simulation mode.");
        const commandList = JSON.parse(commandJsonString);
        window.setSequencerState('running');
        sequencer?.runCommandSequence(commandList).then(() => {
          window.setSequencerState('idle');
        });
      } else {
        console.log("Running on Robot via BLE.");
        runCommandsOnRobot(commandJsonString);
      }
    }
  });

  btStatusButton.addEventListener('click', () => {
    if (window.astroidAppChannel) {
      window.astroidAppChannel('{"event":"show_bt_status"}');
    } else {
      console.log("Cannot show BT status, 'astroidAppChannel' not found.");
    }
  });

  const handlePopState = () => {
    if (!simulatorContainer) {
      return;
    }
    if (simulatorContainer.classList.contains('fullscreen')) {
      simulatorContainer.classList.remove('fullscreen');
      setFullscreenIconState(false);
      if (hasStoredBounds(simulatorContainer)) {
        restoreSimulatorBounds(simulatorContainer);
        clearStoredBounds(simulatorContainer);
      }
    }
  };

  fullscreenButton?.addEventListener('click', (e) => {
    e.stopPropagation();

    if (!simulatorContainer) {
      return;
    }

    const enteringFullscreen = !simulatorContainer.classList.contains('fullscreen');

    if (enteringFullscreen) {
      storeSimulatorBounds(simulatorContainer);
      simulatorContainer.classList.add('fullscreen');
      simulatorContainer.style.left = '';
      simulatorContainer.style.top = '';
      simulatorContainer.style.right = '';
      simulatorContainer.style.bottom = '';
      simulatorContainer.style.width = '';
      simulatorContainer.style.height = '';
    } else {
      simulatorContainer.classList.remove('fullscreen');
      if (hasStoredBounds(simulatorContainer)) {
        restoreSimulatorBounds(simulatorContainer);
        clearStoredBounds(simulatorContainer);
      }
    }

    setFullscreenIconState(enteringFullscreen);

    if (enteringFullscreen) {
      window.addEventListener('popstate', handlePopState, { once: true });
    } else {
      window.removeEventListener('popstate', handlePopState);
    }
  });

  const updateMode = () => {
    isSimulateMode = modeCheckbox.checked;

    simLabel?.classList.toggle('active', isSimulateMode);
    runLabel?.classList.toggle('active', !isSimulateMode);
  };
  modeCheckbox?.addEventListener('change', updateMode);
  updateMode();
}

function createNewProject(data: any) {
  const newId = `proj-${Date.now()}`;
  const newProject = {
    id: newId,
    name: `New Adventure ${data.projects.length + 1}`,
    last_modified: Date.now(),
    workspace_json: INITIAL_WORKSPACE_JSON,
    thumbnail_data: null
  };
  data.projects.push(newProject);
  data.last_opened_id = newId;

  saveProjectsData(data);

  suppressSaveIndicator = true;
  try {
    Blockly.serialization.workspaces.load(INITIAL_WORKSPACE_JSON, primaryWorkspace);
  } finally {
    suppressSaveIndicator = false;
  }
  applyActiveProject(newProject);

  void generateWorkspaceThumbnail().then((thumbnail) => {
    if (!thumbnail) {
      return;
    }
    const refreshedData = getProjectsData();
    const projectIndex = refreshedData.projects.findIndex((p: Project) => p.id === newId);
    if (projectIndex !== -1) {
      refreshedData.projects[projectIndex].thumbnail_data = thumbnail;
      saveProjectsData(refreshedData);
    }
  }).catch((error) => {
    console.warn('Unable to capture thumbnail for new project', error);
  });
}

initializeWorkspace();
