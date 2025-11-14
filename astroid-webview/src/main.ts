// src/main.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';
import { ContinuousCategory } from '@blockly/continuous-toolbox';

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

function initializeDefaultProjects() {
  const data = getProjectsData();
  
  // Only initialize if there are no projects yet
  if (data.projects.length > 0) {
    return;
  }
  
  console.log('First time launch - creating default example projects');
  
  const now = Date.now();
  
  // Project 1: Rainbow LED
  const rainbowLedProject = {
    id: `proj-${now}`,
    name: 'Rainbow LED',
    last_modified: now,
    workspace_json: {
      blocks: {
        languageVersion: 0,
        blocks: [
          {
            type: 'program_start',
            id: 'start_block',
            x: 200,
            y: 100,
            deletable: false,
            movable: false,
            next: {
              block: {
                type: 'looks_set_single_led',
                id: 'led1',
                fields: { LED_ID: 1, COLOR: '#0800ff' },
                next: {
                  block: {
                    type: 'looks_set_single_led',
                    id: 'led2',
                    fields: { LED_ID: 2, COLOR: '#8800ff' },
                    next: {
                      block: {
                        type: 'looks_set_single_led',
                        id: 'led3',
                        fields: { LED_ID: 3, COLOR: '#ff00f7' },
                        next: {
                          block: {
                            type: 'looks_set_single_led',
                            id: 'led4',
                            fields: { LED_ID: 4, COLOR: '#ff0077' },
                            next: {
                              block: {
                                type: 'looks_set_single_led',
                                id: 'led5',
                                fields: { LED_ID: 5, COLOR: '#ff0900' },
                                next: {
                                  block: {
                                    type: 'looks_set_single_led',
                                    id: 'led6',
                                    fields: { LED_ID: 6, COLOR: '#ff8800' },
                                    next: {
                                      block: {
                                        type: 'looks_set_single_led',
                                        id: 'led7',
                                        fields: { LED_ID: 7, COLOR: '#f7ff00' },
                                        next: {
                                          block: {
                                            type: 'looks_set_single_led',
                                            id: 'led8',
                                            fields: { LED_ID: 8, COLOR: '#77ff00' },
                                            next: {
                                              block: {
                                                type: 'looks_set_single_led',
                                                id: 'led9',
                                                fields: { LED_ID: 9, COLOR: '#00ff08' },
                                                next: {
                                                  block: {
                                                    type: 'looks_set_single_led',
                                                    id: 'led10',
                                                    fields: { LED_ID: 10, COLOR: '#00ff88' },
                                                    next: {
                                                      block: {
                                                        type: 'looks_set_single_led',
                                                        id: 'led11',
                                                        fields: { LED_ID: 11, COLOR: '#00f7ff' },
                                                        next: {
                                                          block: {
                                                            type: 'looks_set_single_led',
                                                            id: 'led12',
                                                            fields: { LED_ID: 12, COLOR: '#0077ff' }
                                                          }
                                                        }
                                                      }
                                                    }
                                                  }
                                                }
                                              }
                                            }
                                          }
                                        }
                                      }
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        ]
      }
    },
    thumbnail_data: null
  };

  // Project 2: Obstacle Detection
  const obstacleDetectionProject = {
    id: `proj-${now + 1}`,
    name: 'Obstacle Detection',
    last_modified: now + 1,
    workspace_json: {
      blocks: {
        languageVersion: 0,
        blocks: [
          {
            type: 'program_start',
            id: 'start_block',
            x: 200,
            y: 100,
            deletable: false,
            movable: false,
            next: {
              block: {
                type: 'controls_forever',
                id: 'forever_loop',
                inputs: {
                  DO: {
                    block: {
                      type: 'controls_if',
                      id: 'if_obstacle',
                      extraState: { hasElse: true },
                      inputs: {
                        IF0: {
                          block: {
                            type: 'logic_compare',
                            id: 'compare_distance',
                            fields: { OP: 'LT' },
                            inputs: {
                              A: {
                                block: {
                                  type: 'sensor_get_distance',
                                  id: 'ultrasonic_sensor'
                                }
                              },
                              B: {
                                block: {
                                  type: 'math_number',
                                  id: 'threshold_distance',
                                  fields: { NUM: 0.4 }
                                }
                              }
                            }
                          }
                        },
                        DO0: {
                          block: {
                            type: 'motor_turn_timed',
                            id: 'turn_left',
                            fields: { DIRECTION: 'left', SPEED: 50 },
                            inputs: {
                              DURATION: {
                                shadow: {
                                  type: 'math_number',
                                  id: 'turn_duration',
                                  fields: { NUM: 1 }
                                }
                              }
                            }
                          }
                        },
                        ELSE: {
                          block: {
                            type: 'motor_move_timed',
                            id: 'move_forward',
                            fields: { DIRECTION: 'forward', SPEED: 100 },
                            inputs: {
                              DURATION: {
                                shadow: {
                                  type: 'math_number',
                                  id: 'move_duration',
                                  fields: { NUM: 0.25 }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        ]
      }
    },
    thumbnail_data: null
  };
  
  data.projects = [rainbowLedProject, obstacleDetectionProject];
  data.last_opened_id = rainbowLedProject.id;
  
  saveProjectsData(data);
  console.log('Default projects created successfully');
}

document.addEventListener('pointermove', (event: PointerEvent) => {
  lastPointerPosition.x = event.clientX;
  lastPointerPosition.y = event.clientY;
  updateTrashZoneHighlight();
});

backButton?.addEventListener('click', () => {
  localStorage.removeItem('astroid_active_challenge');
  console.log('Cleared active challenge state on back navigation');
  
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
makeResizable(simulatorContainerElement, simulatorResizeHandle, simulatorHeader);

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
    
    if ((window as any).isChallengeMode) {
      const isFullscreen = simulatorContainer.classList.contains('fullscreen');
      const challengeMetrics = document.getElementById('challenge-metrics');
      const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
      
      if (isFullscreen) {
        challengeMetrics?.style.setProperty('display', 'none');
        challengeMetricsFullscreen?.style.setProperty('display', 'inline-flex');
      } else {
        challengeMetrics?.style.setProperty('display', 'inline-flex');
        challengeMetricsFullscreen?.style.setProperty('display', 'none');
      }
    }
  } else {
    if (simulatorContainer.classList.contains('fullscreen')) {
      simulatorContainer.classList.remove('fullscreen');
      setFullscreenIconState(false);
      if (hasStoredBounds(simulatorContainer)) {
        restoreSimulatorBounds(simulatorContainer);
        clearStoredBounds(simulatorContainer);
      }
      
      if ((window as any).isChallengeMode) {
        const challengeMetrics = document.getElementById('challenge-metrics');
        const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
        challengeMetrics?.style.setProperty('display', 'inline-flex');
        challengeMetricsFullscreen?.style.setProperty('display', 'none');
      }
    }
    
    if ((window as any).isChallengeMode) {
      const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
      challengeMetricsFullscreen?.style.setProperty('display', 'none');
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

function makeResizable(element: HTMLElement | null, handle: HTMLElement | null, header: HTMLElement | null) {
  if (!element || !handle || !header) {
    return;
  }

  const ASPECT_RATIO = 16 / 9;

  handle.addEventListener('pointerdown', (event: PointerEvent) => {
    if (element.classList.contains('fullscreen')) {
      return;
    }

    event.preventDefault();
    
    const measuredHeaderHeight = header.offsetHeight;

    const startWidth = element.offsetWidth;
    const startX = event.clientX;

    const onPointerMove = (moveEvent: PointerEvent) => {
      const deltaX = moveEvent.clientX - startX;

      const minWidth = 200;
      const maxWidth = window.innerWidth - element.getBoundingClientRect().left - 16;

      let newWidth = Math.max(minWidth, startWidth + deltaX);
      newWidth = Math.min(newWidth, maxWidth);
      
      const newCanvasHeight = newWidth / ASPECT_RATIO;
      
      const newHeight = newCanvasHeight + measuredHeaderHeight;

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
  console.log(`getProjectList called - Found ${data.projects.length} projects`);
  const projectList = data.projects.map((p: Project) => ({
    id: p.id,
    name: p.name,
    last_modified: p.last_modified,
    thumbnail_data: p.thumbnail_data ?? null
  }));
  const result = JSON.stringify(projectList);
  console.log('Returning project list:', result.substring(0, 200) + '...');
  return result;
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

(window as any).getChallengeProgress = (): string => {
  const progress = localStorage.getItem('astroid_challenge_progress');
  return progress || '{}';
};

function registerCustomToolboxComponents() {
  Blockly.registry.register(
    Blockly.registry.Type.TOOLBOX_ITEM,
    Blockly.ToolboxCategory.registrationName,
    ContinuousCategory,
    true
  );
}

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

  registerCustomToolboxComponents();

  const workspaceConfig: Blockly.BlocklyOptions = {
    theme: getAstroidTheme(),
    toolbox: getAstroidToolbox(),
    renderer: "zelos",
    toolboxPosition: 'start',
    trashcan: false,
    zoom: { controls: false, wheel: true, startScale: 0.5, maxScale: 1.25, minScale: 0.4, scaleSpeed: 1.05 },
    grid: { spacing: 20, length: 3, colour: '#444', snap: true },
    move: { scrollbars: true, drag: true, wheel: true },
  };

  primaryWorkspace = Blockly.inject(blocklyDiv, workspaceConfig);

  primaryWorkspace.addChangeListener((event: Blockly.Events.Abstract) => {
    if (event.type === Blockly.Events.TOOLBOX_ITEM_SELECT) {
      const selectEvent = event as any;
      const categoryName = selectEvent.newItem;
      
      const categoryColors: { [key: string]: string } = {
        'Motion': 'rgba(8, 65, 140, 0.75)',
        'Parts': 'rgba(0, 100, 110, 0.75)',
        'Looks': 'rgba(80, 55, 145, 0.75)',
        'Sound': 'rgba(130, 20, 90, 0.75)',
        'Control': 'rgba(155, 65, 15, 0.75)',
        'Operators': 'rgba(40, 120, 45, 0.75)',
        'Sensors': 'rgba(5, 90, 110, 0.75)',
      };
      
      const categoryHoverColors: { [key: string]: string } = {
        'Motion': 'rgba(13, 101, 217, 0.2)',
        'Parts': 'rgba(0, 161, 170, 0.2)',
        'Looks': 'rgba(128, 87, 227, 0.2)',
        'Sound': 'rgba(207, 34, 146, 0.2)',
        'Control': 'rgba(244, 103, 24, 0.2)',
        'Operators': 'rgba(64, 191, 74, 0.2)',
        'Sensors': 'rgba(8, 145, 178, 0.2)',
      };
      
      const color = categoryColors[categoryName] || 'rgba(60, 64, 72, 0.8)';
      const hoverColor = categoryHoverColors[categoryName] || 'rgba(255, 255, 255, 0.2)';
      
      document.documentElement.style.setProperty('--flyout-bg-color', color);
      document.documentElement.style.setProperty('--category-hover-color', hoverColor);
    }
  });

  primaryWorkspace.addChangeListener((event: Blockly.Events.Abstract) => {
    if ((window as any).isChallengeMode && !sequencerRunning) {
      if (event.type === Blockly.Events.BLOCK_CREATE || 
          event.type === Blockly.Events.BLOCK_DELETE ||
          event.type === Blockly.Events.BLOCK_MOVE) {
        const blockCount = primaryWorkspace?.getAllBlocks(false).filter(block => !block.isShadow()).length || 0;
        const blockString = `${blockCount} block${blockCount !== 1 ? 's' : ''}`;
        
        const blocksEl = document.getElementById('metric-blocks');
        const blocksElFullscreen = document.getElementById('metric-blocks-fullscreen');
        if (blocksEl) blocksEl.textContent = blockString;
        if (blocksElFullscreen) blocksElFullscreen.textContent = blockString;
      }
    }
  });

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

  if (action === 'load_challenge' && projectId) {
    const levelId = parseInt(projectId, 10);
    if (!isNaN(levelId)) {
      initializeChallengeMode(levelId, sequencer).catch(err => {
        console.error('Failed to load challenge level:', err);
        alert('Failed to load challenge level. Returning to home.');
        if (window.astroidAppChannel) {
          window.astroidAppChannel('{"event":"navigate_home"}');
        }
      });
    }
  } else if (action !== 'open' && action !== 'new_project') {
    // Only restore challenge if we're not explicitly opening/creating a project
    const activeChallengeData = localStorage.getItem('astroid_active_challenge');
    if (activeChallengeData) {
      try {
        const challengeState = JSON.parse(activeChallengeData);
        console.log(`Restoring active challenge: ${challengeState.levelName}`);
        initializeChallengeMode(challengeState.levelId, sequencer).catch(err => {
          console.error('Failed to restore challenge:', err);
          localStorage.removeItem('astroid_active_challenge');
        });
      } catch (e) {
        console.error('Failed to parse challenge state:', e);
        localStorage.removeItem('astroid_active_challenge');
      }
    }
  }

  // Initialize default example projects on first launch
  initializeDefaultProjects();

  let data = getProjectsData();

  resetButton?.addEventListener('click', () => {
    if (!primaryWorkspace) return;
    
    if ((window as any).isChallengeMode) {
      const shouldReset = window.confirm('Reset challenge? This will reload the page and reset everything (your code is auto-saved).');
      if (!shouldReset) return;
      
      window.location.reload();
    } else {
      const shouldReset = window.confirm('Reset workspace to starter blocks? This action cannot be undone.');
      if (!shouldReset) return;
      
      Blockly.serialization.workspaces.load(INITIAL_WORKSPACE_JSON, primaryWorkspace);
      setSaveState('unsaved');
    }
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
    // Clear any active challenge state when opening a regular project
    localStorage.removeItem('astroid_active_challenge');
    console.log('Cleared active challenge state for regular project');
    
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
    // Clear any active challenge state when creating a new project
    localStorage.removeItem('astroid_active_challenge');
    console.log('Cleared active challenge state for new project');
    
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

    if ((window as any).isChallengeMode) {
      const levelId = (window as any).currentChallengeLevel?.id;
      if (levelId) {
        if (saveTimeout !== null) {
          clearTimeout(saveTimeout);
        }
        saveTimeout = window.setTimeout(() => {
          const workspaceJson = Blockly.serialization.workspaces.save(primaryWorkspace);
          const challengeWorkspaces = JSON.parse(localStorage.getItem('astroid_challenge_workspaces') || '{}');
          challengeWorkspaces[`level_${levelId}`] = {
            workspace: workspaceJson,
            lastModified: Date.now()
          };
          localStorage.setItem('astroid_challenge_workspaces', JSON.stringify(challengeWorkspaces));
          console.log(`Challenge level ${levelId} workspace auto-saved`);
        }, 1000);
      }
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
      if (isSimulateMode || (window as any).isChallengeMode) {
        sequencer?.stopSequence();
        window.setSequencerState('idle');
        
        if ((window as any).isChallengeMode) {
          sequencer?.endChallengeRun(false);
          stopMetricsTimer();
        }
      } else {
        if (window.astroidAppChannel) {
          window.astroidAppChannel('{"event":"stop_code"}');
        }
      }
    } else {
      // Prevent running again after winning
      if ((window as any).isChallengeMode && (window as any).challengeWon) {
        alert('Challenge already completed! 🎉\n\nYou can reset to try again or go back to level selection.');
        return;
      }

      const commandJsonString = window.generateCodeForExecution();

      if ((window as any).isChallengeMode || isSimulateMode) {
        console.log((window as any).isChallengeMode ? "Running Challenge Mode." : "Running in Simulation mode.");
        const commandList = JSON.parse(commandJsonString);
        
        if ((window as any).isChallengeMode) {
          (window as any).challengeAttemptNumber++;
          sequencer?.startChallengeRun((window as any).challengeAttemptNumber);
          
          startMetricsTimer();
        }
        
        window.setSequencerState('running');
        sequencer?.runCommandSequence(commandList).then(() => {
          window.setSequencerState('idle');
          
          if ((window as any).isChallengeMode) {
            const won = sequencer?.checkWinCondition() || false;
            sequencer?.endChallengeRun(won);
            
            // Always stop timer when simulation ends
            stopMetricsTimer();
            
            if (won) {
              (window as any).challengeWon = true; // Mark as won
              evaluateChallengeStars(sequencer);
            }
          }
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
      
      if ((window as any).isChallengeMode) {
        const challengeMetrics = document.getElementById('challenge-metrics');
        const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
        challengeMetrics?.style.setProperty('display', 'inline-flex');
        challengeMetricsFullscreen?.style.setProperty('display', 'none');
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
      
      if ((window as any).isChallengeMode) {
        const challengeMetrics = document.getElementById('challenge-metrics');
        const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
        challengeMetrics?.style.setProperty('display', 'none');
        challengeMetricsFullscreen?.style.setProperty('display', 'inline-flex');
      }
    } else {
      simulatorContainer.classList.remove('fullscreen');
      if (hasStoredBounds(simulatorContainer)) {
        restoreSimulatorBounds(simulatorContainer);
        clearStoredBounds(simulatorContainer);
      }
      
      if ((window as any).isChallengeMode) {
        const challengeMetrics = document.getElementById('challenge-metrics');
        const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
        challengeMetrics?.style.setProperty('display', 'inline-flex');
        challengeMetricsFullscreen?.style.setProperty('display', 'none');
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

async function initializeChallengeMode(levelId: number, sequencer: SimulatorSequencer | null) {
  if (!sequencer) {
    throw new Error('Sequencer not initialized');
  }

  console.log(`Initializing Challenge Mode - Level ${levelId}`);

  const response = await fetch('levels.json');
  if (!response.ok) {
    throw new Error('Failed to load levels.json');
  }

  const levels = await response.json();
  const level = levels.find((l: any) => l.id === levelId);

  if (!level) {
    throw new Error(`Level ${levelId} not found`);
  }

  (window as any).isChallengeMode = true;
  (window as any).currentChallengeLevel = level;
  (window as any).challengeAttemptNumber = 0;
  (window as any).challengeWon = false; // Track if challenge is already won
  
  localStorage.setItem('astroid_active_challenge', JSON.stringify({
    levelId: levelId,
    levelName: level.name,
    timestamp: Date.now()
  }));

  sequencer.loadLevel(level);

  const modeCheckbox = document.getElementById('mode-checkbox') as HTMLInputElement;
  if (modeCheckbox) {
    modeCheckbox.checked = true;
    
    const event = new Event('change');
    modeCheckbox.dispatchEvent(event);
  }

  hideSandboxUI();

  createStarConditionsPanel(level);

  suppressSaveIndicator = true;
  try {
    const challengeWorkspaces = JSON.parse(localStorage.getItem('astroid_challenge_workspaces') || '{}');
    const savedWorkspace = challengeWorkspaces[`level_${levelId}`];
    
    if (savedWorkspace && savedWorkspace.workspace) {
      console.log(`Loading saved workspace for level ${levelId}`);
      Blockly.serialization.workspaces.load(savedWorkspace.workspace, primaryWorkspace);
    } else {
      console.log(`No saved workspace found, loading initial blocks for level ${levelId}`);
      Blockly.serialization.workspaces.load(INITIAL_WORKSPACE_JSON, primaryWorkspace);
    }
  } finally {
    suppressSaveIndicator = false;
  }

  console.log(`Challenge Mode Initialized: ${level.name}`);
}

function hideSandboxUI() {
  const projectNameInput = document.getElementById('project-name-input');
  const saveIndicator = document.getElementById('save-indicator');
  const btStatusButton = document.getElementById('bt-status-button');
  const modeToggle = document.getElementById('app-mode-toggle');
  const challengeMetrics = document.getElementById('challenge-metrics');
  const challengeMetricsFullscreen = document.getElementById('challenge-metrics-fullscreen');
  const viewToggleChat = document.getElementById('view-toggle-chat');

  projectNameInput?.style.setProperty('display', 'none');
  saveIndicator?.style.setProperty('display', 'none');
  btStatusButton?.style.setProperty('display', 'none');
  modeToggle?.style.setProperty('display', 'none');
  
  if (viewToggleChat) {
    viewToggleChat.style.setProperty('opacity', '0.4');
    viewToggleChat.style.setProperty('cursor', 'not-allowed');
    viewToggleChat.setAttribute('data-disabled', 'true');
    
    const newChatButton = viewToggleChat.cloneNode(true) as HTMLElement;
    viewToggleChat.parentNode?.replaceChild(newChatButton, viewToggleChat);
    
    newChatButton.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      showToast('AI Chat for challenge will be implemented soon!');
    });
  }
  
  challengeMetrics?.style.setProperty('display', 'inline-flex');
  challengeMetricsFullscreen?.style.setProperty('display', 'none');

  console.log('Sandbox UI hidden for Challenge Mode (Chat AI disabled)');
}

function showToast(message: string) {
  const existingToast = document.getElementById('challenge-toast');
  if (existingToast) {
    existingToast.remove();
  }

  const toast = document.createElement('div');
  toast.id = 'challenge-toast';
  toast.style.cssText = `
    position: fixed;
    bottom: 80px;
    left: 50%;
    transform: translateX(-50%);
    background: linear-gradient(135deg, rgba(17, 32, 61, 0.95), rgba(30, 50, 90, 0.95));
    color: #E0E8F0;
    padding: 14px 24px;
    border-radius: 12px;
    border: 1px solid rgba(65, 216, 255, 0.4);
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.5);
    font-family: 'Segoe UI', system-ui, sans-serif;
    font-size: 14px;
    font-weight: 500;
    z-index: 10000;
    animation: slideUpFade 0.3s ease;
    backdrop-filter: blur(10px);
  `;
  toast.textContent = message;
  
  const style = document.createElement('style');
  style.textContent = `
    @keyframes slideUpFade {
      from {
        opacity: 0;
        transform: translate(-50%, 20px);
      }
      to {
        opacity: 1;
        transform: translate(-50%, 0);
      }
    }
    @keyframes slideDownFade {
      from {
        opacity: 1;
        transform: translate(-50%, 0);
      }
      to {
        opacity: 0;
        transform: translate(-50%, 20px);
      }
    }
  `;
  
  if (!document.getElementById('toast-animations')) {
    style.id = 'toast-animations';
    document.head.appendChild(style);
  }
  
  document.body.appendChild(toast);
  
  setTimeout(() => {
    toast.style.animation = 'slideDownFade 0.3s ease';
    setTimeout(() => {
      toast.remove();
    }, 300);
  }, 3000);
}

function updateChallengeMetrics() {
  if (!(window as any).isChallengeMode) return;

  const challengeMetrics = (window as any).challengeMetrics;
  if (!challengeMetrics) return;

  let elapsedTime = challengeMetrics.accumulatedTime || 0;
  if (challengeMetrics.currentRunStartTime) {
    elapsedTime += Math.floor((Date.now() - challengeMetrics.currentRunStartTime) / 1000);
  }
  
  const minutes = Math.floor(elapsedTime / 60);
  const seconds = elapsedTime % 60;
  const timeString = `${minutes}:${seconds.toString().padStart(2, '0')}`;
  
  const timeEl = document.getElementById('metric-time');
  const timeElFullscreen = document.getElementById('metric-time-fullscreen');
  if (timeEl) timeEl.textContent = timeString;
  if (timeElFullscreen) timeElFullscreen.textContent = timeString;

  const blockCount = primaryWorkspace?.getAllBlocks(false).filter(block => !block.isShadow()).length || 0;
  const blockString = `${blockCount} block${blockCount !== 1 ? 's' : ''}`;
  
  const blocksEl = document.getElementById('metric-blocks');
  const blocksElFullscreen = document.getElementById('metric-blocks-fullscreen');
  if (blocksEl) blocksEl.textContent = blockString;
  if (blocksElFullscreen) blocksElFullscreen.textContent = blockString;

  const attemptNumber = (window as any).challengeAttemptNumber || 1;
  const attemptString = `Attempt #${attemptNumber}`;
  
  const attemptsEl = document.getElementById('metric-attempts');
  const attemptsElFullscreen = document.getElementById('metric-attempts-fullscreen');
  if (attemptsEl) attemptsEl.textContent = attemptString;
  if (attemptsElFullscreen) attemptsElFullscreen.textContent = attemptString;
}

function startMetricsTimer() {
  if (!(window as any).challengeMetrics) {
    (window as any).challengeMetrics = {
      accumulatedTime: 0,
      currentRunStartTime: null
    };
  }
  
  const metrics = (window as any).challengeMetrics;
  
  metrics.currentRunStartTime = Date.now();
  
  if ((window as any).metricsInterval) {
    clearInterval((window as any).metricsInterval);
  }
  (window as any).metricsInterval = setInterval(updateChallengeMetrics, 100);
  updateChallengeMetrics();
}

function stopMetricsTimer() {
  const metrics = (window as any).challengeMetrics;
  
  if (metrics && metrics.currentRunStartTime) {
    const currentRunTime = Math.floor((Date.now() - metrics.currentRunStartTime) / 1000);
    metrics.accumulatedTime = (metrics.accumulatedTime || 0) + currentRunTime;
    metrics.currentRunStartTime = null;
  }
  
  if ((window as any).metricsInterval) {
    clearInterval((window as any).metricsInterval);
    (window as any).metricsInterval = null;
  }
  
  updateChallengeMetrics();
}

function createStarConditionsPanel(level: any) {
  const backdrop = document.createElement('div');
  backdrop.id = 'star-conditions-backdrop';
  backdrop.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.7);
    backdrop-filter: blur(10px);
    z-index: 9998;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 20px;
    animation: fadeIn 0.3s ease;
  `;
  
  const panel = document.createElement('div');
  panel.id = 'star-conditions-panel';
  panel.style.cssText = `
    position: relative;
    background: linear-gradient(135deg, rgba(17, 32, 61, 0.98), rgba(30, 50, 90, 0.98));
    border: 2px solid rgba(65, 216, 255, 0.6);
    border-radius: 20px;
    padding: 0;
    width: 100%;
    max-width: 700px;
    max-height: 85vh;
    box-shadow: 0 20px 60px rgba(0, 0, 0, 0.6);
    font-family: 'Segoe UI', system-ui, sans-serif;
    z-index: 9999;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    animation: slideIn 0.3s ease;
  `;

  const difficultyColors: Record<string, string> = {
    easy: '#4CAF50',
    medium: '#FF9800',
    hard: '#F44336'
  };

  const header = document.createElement('div');
  header.style.cssText = `
    padding: 24px 30px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    border-bottom: 1px solid rgba(65, 216, 255, 0.3);
    flex-shrink: 0;
  `;
  
  const titleDiv = document.createElement('div');
  titleDiv.style.cssText = `flex: 1;`;
  titleDiv.innerHTML = `
    <h2 style="margin: 0; color: #41D8FF; font-size: 24px; font-weight: 700;">
      ⭐ Challenge Mission
    </h2>
  `;
  
  const closeBtn = document.createElement('button');
  closeBtn.id = 'star-panel-close';
  closeBtn.style.cssText = `
    background: rgba(65, 216, 255, 0.15);
    border: 1px solid rgba(65, 216, 255, 0.4);
    border-radius: 8px;
    color: #41D8FF;
    cursor: pointer;
    padding: 8px 12px;
    font-size: 18px;
    font-weight: bold;
    transition: all 0.2s ease;
    flex-shrink: 0;
  `;
  closeBtn.innerHTML = '✕';
  closeBtn.title = 'I understand, let me code!';
  closeBtn.onmouseenter = () => {
    closeBtn.style.background = 'rgba(65, 216, 255, 0.25)';
    closeBtn.style.transform = 'scale(1.1)';
  };
  closeBtn.onmouseleave = () => {
    closeBtn.style.background = 'rgba(65, 216, 255, 0.15)';
    closeBtn.style.transform = 'scale(1)';
  };
  
  header.appendChild(titleDiv);
  header.appendChild(closeBtn);

  const contentDiv = document.createElement('div');
  contentDiv.id = 'star-panel-content';
  contentDiv.style.cssText = `
    padding: 24px 30px;
    overflow-y: auto;
    overflow-x: hidden;
    flex: 1;
    min-height: 0;
  `;
  
  contentDiv.innerHTML = `
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 24px; align-items: start;">
      <!-- Left Column: Challenge Info -->
      <div style="padding-right: 12px;">
        <div style="margin-bottom: 16px;">
          <div style="display: inline-block; padding: 6px 16px; background: ${difficultyColors[level.difficulty]}; border-radius: 16px; font-size: 12px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; box-shadow: 0 2px 8px rgba(0,0,0,0.3); margin-bottom: 16px;">
            ${level.difficulty}
          </div>
          <h3 style="margin: 0 0 16px 0; color: #FFF; font-size: 26px; font-weight: 700; line-height: 1.2;">
            ${level.name}
          </h3>
          <p style="margin: 0; color: #D0DCE8; font-size: 15px; line-height: 1.7;">
            ${level.description}
          </p>
        </div>
      </div>
      
      <!-- Right Column: Star Objectives -->
      <div style="padding-left: 12px; border-left: 2px solid rgba(65, 216, 255, 0.3);">
        <h3 style="margin: 0 0 16px 0; color: #FFF; font-size: 18px; font-weight: 700; display: flex; align-items: center; gap: 8px;">
          <span>⭐</span>
          <span>Star Objectives</span>
        </h3>
        <div id="star-list" style="display: grid; gap: 10px;">
          ${level.stars.map((star: any, index: number) => `
            <div class="star-item" data-star-index="${index}" style="display: flex; align-items: center; gap: 12px; padding: 12px 14px; background: linear-gradient(135deg, rgba(255, 255, 255, 0.08), rgba(255, 255, 255, 0.04)); border-radius: 10px; border: 1px solid rgba(255, 255, 255, 0.1); transition: all 0.2s ease;">
              <svg class="star-icon" width="20" height="20" viewBox="0 0 24 24" style="fill: #666; flex-shrink: 0; transition: all 0.2s ease;">
                <path d="M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z"/>
              </svg>
              <span style="color: #E0E8F0; font-size: 14px; line-height: 1.5; font-weight: 500;">
                ${star.label}
              </span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>
    
    <div style="text-align: center; margin-top: 30px; padding-top: 24px; border-top: 1px solid rgba(65, 216, 255, 0.2);">
      <p style="color: #41D8FF; font-size: 14px; font-weight: 600; margin: 0;">
        💡 Click the ✕ button above when you're ready to start coding!
      </p>
    </div>
  `;

  panel.appendChild(header);
  panel.appendChild(contentDiv);
  backdrop.appendChild(panel);
  document.body.appendChild(backdrop);
  
  const style = document.createElement('style');
  style.textContent = `
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }
    @keyframes slideIn {
      from { transform: translateY(-30px); opacity: 0; }
      to { transform: translateY(0); opacity: 1; }
    }
    @keyframes fadeOut {
      from { opacity: 1; }
      to { opacity: 0; }
    }
    @keyframes slideOut {
      from { transform: translateY(0); opacity: 1; }
      to { transform: translateY(-20px); opacity: 0; }
    }
  `;
  document.head.appendChild(style);

  closeBtn.addEventListener('click', () => {
    backdrop.style.animation = 'fadeOut 0.2s ease';
    panel.style.animation = 'slideOut 0.2s ease';
    setTimeout(() => {
      backdrop.style.display = 'none';
      const challengeInfoBtn = document.getElementById('challenge-info-button');
      if (challengeInfoBtn) {
        challengeInfoBtn.style.display = 'block';
      }
    }, 200);
  });

  const challengeInfoBtn = document.getElementById('challenge-info-button');
  if (challengeInfoBtn) {
    challengeInfoBtn.style.display = 'none';
    challengeInfoBtn.addEventListener('click', () => {
      backdrop.style.display = 'flex';
      backdrop.style.animation = 'fadeIn 0.3s ease';
      panel.style.animation = 'slideIn 0.3s ease';
      challengeInfoBtn.style.display = 'none';
    });
  }

  console.log('Star conditions panel created with full-screen overlay');
}

function evaluateChallengeStars(sequencer: SimulatorSequencer | null) {
  if (!sequencer) return;

  const level = (window as any).currentChallengeLevel;
  if (!level) return;

  const metrics = sequencer.getChallengeMetrics();
  if (!metrics) return;

  const elapsedMs = metrics.endTime - metrics.startTime;
  const elapsedSeconds = elapsedMs / 1000;

  // Filter out shadow blocks to match metrics display
  const blockCount = primaryWorkspace.getAllBlocks(false).filter(block => !block.isShadow()).length;

  const blocksUsed = primaryWorkspace.getAllBlocks(false).map((block: Blockly.Block) => block.type);

  const earnedStars: boolean[] = [];

  console.log(`Evaluating stars - Time: ${elapsedSeconds.toFixed(2)}s, Blocks: ${blockCount}, Collisions: ${metrics.collisionCount}, Attempt: ${metrics.attemptNumber}`);

  level.stars.forEach((star: any, index: number) => {
    let earned = false;

    switch (star.type) {
      case 'time':
        earned = elapsedMs <= star.value;
        console.log(`Star ${index} (Time): ${earned ? '✓' : '✗'} (${elapsedMs}ms <= ${star.value}ms)`);
        break;

      case 'maxBlocks':
        earned = blockCount <= star.value;
        console.log(`Star ${index} (MaxBlocks): ${earned ? '✓' : '✗'} (${blockCount} <= ${star.value})`);
        break;

      case 'requireBlocks':
        earned = star.value.every((requiredType: string) => blocksUsed.includes(requiredType));
        console.log(`Star ${index} (RequireBlocks): ${earned ? '✓' : '✗'}`);
        break;

      case 'noHits':
        earned = metrics.collisionCount === 0;
        console.log(`Star ${index} (NoHits): ${earned ? '✓' : '✗'} (${metrics.collisionCount} collisions)`);
        break;

      case 'oneShot':
        earned = metrics.attemptNumber === 1;
        console.log(`Star ${index} (OneShot): ${earned ? '✓' : '✗'} (Attempt #${metrics.attemptNumber})`);
        break;

      case 'proximity':
        earned = (metrics.finalDistance || 999) <= star.value;
        console.log(`Star ${index} (Proximity): ${earned ? '✓' : '✗'} (${metrics.finalDistance?.toFixed(3)}m <= ${star.value}m)`);
        break;

      default:
        console.warn(`Unknown star type: ${star.type}`);
    }

    earnedStars.push(earned);
  });

  updateStarUI(earnedStars);

  saveChallengeProgress(level.id, earnedStars);

  showCompletionMessage(earnedStars.filter(s => s).length, earnedStars.length);
}

function updateStarUI(earnedStars: boolean[]) {
  earnedStars.forEach((earned, index) => {
    const starItem = document.querySelector(`.star-item[data-star-index="${index}"]`);
    if (!starItem) return;

    const starIcon = starItem.querySelector('.star-icon') as SVGElement;
    if (starIcon) {
      starIcon.style.fill = earned ? '#FFD700' : '#555';
      if (earned) {
        starIcon.style.filter = 'drop-shadow(0 0 8px rgba(255, 215, 0, 0.8))';
      }
    }
  });
}

function saveChallengeProgress(levelId: number, earnedStars: boolean[]) {
  const progress = localStorage.getItem('astroid_challenge_progress');
  const progressData = progress ? JSON.parse(progress) : {};

  if (!progressData[levelId]) {
    progressData[levelId] = { stars: [], bestAttempt: 0 };
  }

  for (let i = 0; i < earnedStars.length; i++) {
    if (earnedStars[i]) {
      progressData[levelId].stars[i] = true;
    } else if (progressData[levelId].stars[i] === undefined) {
      progressData[levelId].stars[i] = false;
    }
  }

  const totalStars = progressData[levelId].stars.filter((s: boolean) => s).length;
  progressData[levelId].bestAttempt = Math.max(progressData[levelId].bestAttempt || 0, totalStars);

  localStorage.setItem('astroid_challenge_progress', JSON.stringify(progressData));
  console.log(`Progress saved: Level ${levelId} - ${totalStars}/${earnedStars.length} stars`);
}

function showCompletionMessage(starsEarned: number, totalStars: number) {
  const messages = [
    "Keep trying! You can do better! 💪",
    "Good start! Try to earn more stars! ⭐",
    "Great work! Almost perfect! 🌟",
    "Excellent! You're a master programmer! 🎉"
  ];

  const messageIndex = Math.min(starsEarned, messages.length - 1);
  const message = messages[messageIndex];

  alert(`🎉 Level Complete!\n\nStars Earned: ${starsEarned} / ${totalStars}\n\n${message}`);
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
