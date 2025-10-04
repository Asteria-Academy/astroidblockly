// src/main.ts

import * as Blockly from 'blockly/core';
import './categories';
import { javascriptGenerator } from 'blockly/javascript';
import { ContinuousToolbox, ContinuousFlyout, registerContinuousToolbox } from '@blockly/continuous-toolbox';

// --- Our Project's Core Files ---
import { getAstroidToolbox } from './toolbox';
import { getAstroidTheme, applyAstroidThemeStyles } from './visual/theme';
import { runCommands } from './command_runner';

// --- Get DOM Elements ---
const blocklyDiv = document.getElementById('blockly-div');
const runButton = document.getElementById('run-button');

// --- Main Application State ---
let primaryWorkspace: Blockly.WorkspaceSvg;

function initializeWorkspace() {
  if (!blocklyDiv || !runButton) {
    throw new Error('Required DOM elements not found!');
  }

  registerContinuousToolbox();
  applyAstroidThemeStyles();

  const workspaceConfig: Blockly.BlocklyOptions = {
    // theme: getAstroidTheme(false),
    theme: getAstroidTheme(),
    toolbox: getAstroidToolbox(),
    // toolbox: { kind: 'categoryToolbox', contents: [] },
    renderer: "zelos",
    trashcan: true,
    zoom: { controls: true, wheel: true, startScale: 0.8 },
    grid: { spacing: 20, length: 3, colour: '#ccc', snap: true },
    plugins: {
      toolbox: ContinuousToolbox,
      flyoutsVerticalToolbox: ContinuousFlyout,
    },
  };

  primaryWorkspace = Blockly.inject(blocklyDiv, workspaceConfig);

  runButton.addEventListener('click', handleRunCode);

  console.log("RoboBlox Workspace Initialized!");
}

function handleRunCode() {
  if (!primaryWorkspace) {
    console.error("Workspace is not initialized.");
    return;
  }

  const generatedCode = javascriptGenerator.workspaceToCode(primaryWorkspace);

  runCommands(generatedCode);
}

initializeWorkspace();