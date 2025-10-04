// src/categories/neck.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator, Order } from 'blockly/javascript';
import { astroidV2 } from '../robotProfiles';

// --- Block Definitions ---
Blockly.defineBlocksWithJsonArray([
  {
    "type": "neck_set_angle",
    "message0": "Set Neck %1 to %2 degrees",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "AXIS",
        "options": [
          ["Pitch (Up/Down)", "PITCH"],
          ["Yaw (Left/Right)", "YAW"]
        ]
      },
      {
        "type": "input_value",
        "name": "ANGLE",
        "check": "Number"
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "motion_blocks",
    "tooltip": "Sets the angle of the neck's pitch or yaw servo (0-180 degrees)."
  }
]);

// --- Block Generator ---
javascriptGenerator.forBlock['neck_set_angle'] = function(block, generator) {
  const axis = block.getFieldValue('AXIS');
  const angle = generator.valueToCode(block, 'ANGLE', Order.ATOMIC) || '90';

  const command = axis === 'PITCH'
    ? astroidV2.commands.setNeckPitch
    : astroidV2.commands.setNeckYaw;

  const commandObj = {
    command: command,
    params: {
      angle: parseInt(angle, 10)
    }
  };
  return JSON.stringify(commandObj) + ';';
};

// --- Toolbox Definition ---
export const neckCategory = {
  kind: 'category',
  name: 'Neck',
  categorystyle: 'motion_category',
  contents: [
    {
      kind: 'block',
      type: 'neck_set_angle',
      inputs: {
        ANGLE: {
          shadow: {
            type: 'math_number',
            fields: { NUM: 90 }
          }
        }
      }
    },
  ],
};