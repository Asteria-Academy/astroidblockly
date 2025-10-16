// src/main.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';
import { ContinuousToolbox, ContinuousFlyout, registerContinuousToolbox } from '@blockly/continuous-toolbox';

import { getAstroidToolbox } from './toolbox';
import { getAstroidTheme } from './visual/theme';
import { runCommands } from './command_runner';
import { initializeAstroidEditor } from './core';

declare global {
  interface Window {
    astroidAppChannel: (message: string) => void;
    
    getProjectList: () => string;
    deleteProject: (projectId: string) => void;
    renameProject: (projectId: string, newName: string) => void;
    setSequencerState: (state: 'running' | 'idle') => void;
    updateSequencerState: (state: 'running' | 'idle') => void;
    generateCodeForExecution: () => string;
  }
}

interface Project {
  id: string;
  name: string;
  last_modified: number;
  workspace_json: any;
}

const INITIAL_WORKSPACE_JSON = {
  "blocks": { "languageVersion": 0, "blocks": [
    { "type": "program_start", "id": "start_block", "x": 200, "y": 100, "deletable": false, "movable": false,
      "next": { "block": { "type": "motor_stop" } }
    }
  ]}
};

initializeAstroidEditor();

const blocklyDiv = document.getElementById('blockly-div');
const playButton = document.getElementById('play-button');
const btStatusButton = document.getElementById('bt-status-button');

let primaryWorkspace: Blockly.WorkspaceSvg;
let currentProjectId: string | null = null;
let saveTimeout: number | null = null;

function getProjectsData() {
  const data = localStorage.getItem('astroid_projects');
  if (!data) return { last_opened_id: null, projects: [] };
  try {
    return JSON.parse(data);
  } catch(e) {
    return { last_opened_id: null, projects: [] };
  }
}

function saveProjectsData(data: any) {
  localStorage.setItem('astroid_projects', JSON.stringify(data));
}

(window as any).getProjectList = function() {
  const data = getProjectsData();
  const projectList = data.projects.map((p: Project) => ({
    id: p.id,
    name: p.name,
    last_modified: p.last_modified
  }));
  return JSON.stringify(projectList);
};

(window as any).deleteProject = function(projectId: string) {
  let data = getProjectsData();
  data.projects = data.projects.filter((p: Project) => p.id !== projectId);
  if (data.last_opened_id === projectId) {
    data.last_opened_id = null;
  }
  saveProjectsData(data);
};

(window as any).renameProject = function(projectId: string, newName: string) {
  if (!newName || newName.trim().length === 0) {
    console.error("New project name cannot be empty.");
    return;
  }

  let data = getProjectsData();
  const projectIndex = data.projects.findIndex((p: Project) => p.id === projectId);

  if (projectIndex !== -1) {
    data.projects[projectIndex].name = newName.trim();
    data.projects[projectIndex].last_modified = Date.now();
    saveProjectsData(data);
    console.log(`Project ${projectId} renamed to ${newName}`);
  } else {
    console.error(`Could not find project with ID ${projectId} to rename.`);
  }
};

(window as any).generateCodeForExecution = (): string => {
  if (!primaryWorkspace) return '';
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
  return '[]'; // Return empty JSON array
};

function initializeWorkspace() {
  if (!blocklyDiv || !playButton || !btStatusButton) {
    throw new Error('Required DOM elements not found!');
  }

  registerContinuousToolbox();

  const workspaceConfig: Blockly.BlocklyOptions = {
    theme: getAstroidTheme(),
    toolbox: getAstroidToolbox(),
    renderer: "zelos",
    trashcan: true,
    zoom: { controls: true, wheel: true, startScale: 0.65, maxScale: 1.25, minScale: 0.4, scaleSpeed: 1.05 },
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

  let data = getProjectsData();

  // Local flag that mirrors the authoritative sequencer state from Flutter.
  let sequencerRunning = false;

  window.setSequencerState = (state: 'running' | 'idle') => {
    if (state === 'running') {
      playButton.innerHTML = stopButtonSvg;
      sequencerRunning = true;
    } else {
      playButton.innerHTML = playButtonSvg;
      sequencerRunning = false;
    }
  };

  // Receiver used by Flutter to push sequencer state changes into the WebView.
  window.updateSequencerState = (state: 'running' | 'idle') => {
    // Prefer calling the existing setter so we keep a single place that updates UI.
    window.setSequencerState(state);
  };

  if (action === 'load_project' && projectId) {
    const projectToLoad = data.projects.find((p: Project) => p.id === projectId);
    if (projectToLoad) {
      console.log(`Loading project: ${projectToLoad.name}`);
      Blockly.serialization.workspaces.load(projectToLoad.workspace_json, primaryWorkspace);
      currentProjectId = projectId;
      data.last_opened_id = projectId;
    } else {
      console.error(`Project with ID ${projectId} not found. Starting new.`);
      createNewProject(data);
    }
  } else if (action === 'load_last') {
    const lastProject = data.projects.find((p: Project) => p.id === data.last_opened_id);
    if (lastProject) {
      console.log(`Loading last project: ${lastProject.name}`);
      Blockly.serialization.workspaces.load(lastProject.workspace_json, primaryWorkspace);
      currentProjectId = lastProject.id;
    } else {
      console.log("No last project found, starting new.");
      createNewProject(data);
    }
  } else {
    console.log("Creating a new project.");
    createNewProject(data);
  }

  saveProjectsData(data);

  primaryWorkspace.addChangeListener((event: Blockly.Events.Abstract) => {
    if (event.isUiEvent || primaryWorkspace.isDragging() || !currentProjectId) {
      return;
    }

    if (saveTimeout !== null) {
      clearTimeout(saveTimeout);
    }

    saveTimeout = setTimeout(() => {
      console.log("Debounced save triggered.");
      const workspaceJson = Blockly.serialization.workspaces.save(primaryWorkspace);
      let currentData = getProjectsData();
      const projectIndex = currentData.projects.findIndex((p: Project) => p.id === currentProjectId);

      if (projectIndex !== -1) {
        currentData.projects[projectIndex].workspace_json = workspaceJson;
        currentData.projects[projectIndex].last_modified = Date.now();
        currentData.last_opened_id = currentProjectId;
        saveProjectsData(currentData);
        console.log("Project auto-saved.");
      }
    }, 1000);
  });

  // When the play button is clicked we SHOULD NOT update the UI optimistically.
  // Instead, send a message to Flutter and let Flutter call
  // `window.updateSequencerState` to reflect the authoritative state.
  playButton.addEventListener('click', () => {
    if (sequencerRunning) {
      if (window.astroidAppChannel) {
        window.astroidAppChannel('{"event":"stop_code"}');
      }
    } else {
      // Trigger code generation and send commands to Flutter.
      handleRunCode();
    }
  });

  btStatusButton.addEventListener('click', () => {
    if (window.astroidAppChannel) {
      window.astroidAppChannel('{"event":"show_bt_status"}');
    } else {
      console.log("Cannot show BT status, 'astroidAppChannel' not found.");
    }
  });
}

function createNewProject(data: any) {
    const newId = `proj-${Date.now()}`;
    const newProject = {
        id: newId,
        name: `New Adventure ${data.projects.length + 1}`,
        last_modified: Date.now(),
        workspace_json: INITIAL_WORKSPACE_JSON
    };
    data.projects.push(newProject);
    currentProjectId = newId;
    data.last_opened_id = newId;

    saveProjectsData(data);

    Blockly.serialization.workspaces.load(INITIAL_WORKSPACE_JSON, primaryWorkspace);
}

function handleRunCode() {
  const code = window.generateCodeForExecution();
  runCommands(code);
}

initializeWorkspace();