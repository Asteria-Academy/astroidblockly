// src/categories/gripper.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';
import { astroidV2 } from '../robotProfiles';

// --- Block Definitions ---
Blockly.defineBlocksWithJsonArray([
  {
    "type": "gripper_action",
    "message0": "%1 Gripper",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "ACTION",
        "options": [
          ["Open", "OPEN"],
          ["Close", "CLOSE"]
        ]
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "functions_category",
    "tooltip": "Opens or closes the robot's gripper."
  }
]);

// --- Block Generator ---
javascriptGenerator.forBlock['gripper_action'] = function(block, _generator) {
  const action = block.getFieldValue('ACTION');

  const command = action === 'OPEN'
    ? astroidV2.commands.openGripper
    : astroidV2.commands.closeGripper;

  const commandObj = {
    command: command,
    params: {}
  };
  return JSON.stringify(commandObj) + ';';
};

// --- Toolbox Definition ---
export const gripperCategory = {
  kind: 'category',
  name: 'Gripper',
  categorystyle: 'functions_category',
  contents: [
    {
      kind: 'block',
      type: 'gripper_action'
    },
  ],
};