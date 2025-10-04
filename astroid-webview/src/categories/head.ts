// src/categories/head.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator, Order } from 'blockly/javascript';
import { astroidV2 } from '../robotProfiles';
import '@blockly/field-colour-hsv-sliders';

// --- Block Definitions ---
Blockly.defineBlocksWithJsonArray([
  {
    "type": "head_set_led",
    "message0": "Set LED color to %1",
    "args0": [
      {
        "type": "input_value",
        "name": "COLOR",
        "check": "Colour"
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "looks_blocks",
    "tooltip": "Sets the color of the head's RGB LED."
  },
  {
    "type": "head_show_expression",
    "message0": "Show expression %1",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "EMOTION",
        "options": [
          ["Happy", "HAPPY"],
          ["Sad", "SAD"],
          ["Confused", "CONFUSED"],
          ["Angry", "ANGRY"]
        ]
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "looks_blocks",
    "tooltip": "Displays an expression on the robot's LCD screen."
  }
]);

// --- Block Generators ---
javascriptGenerator.forBlock['head_set_led'] = function(block, generator) {
  const color = generator.valueToCode(block, 'COLOR', Order.ATOMIC) || "'#ffffff'";
  
  const hex = color.replace(/['#]/g, '');
  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);

  const commandObj = {
    command: astroidV2.commands.setLed,
    params: { r, g, b }
  };
  return JSON.stringify(commandObj) + ';';
};

javascriptGenerator.forBlock['head_show_expression'] = function(block, _generator) {
  const emotion = block.getFieldValue('EMOTION');

  const commandObj = {
    command: astroidV2.commands.showExpression,
    params: {
      emotion: emotion
    }
  };
  return JSON.stringify(commandObj) + ';';
};

// --- Toolbox Definition ---
export const headCategory = {
  kind: 'category',
  name: 'Head',
  categorystyle: 'looks_category',
  contents: [
    {
      kind: 'block',
      type: 'head_set_led',
      inputs: {
        COLOR: {
          shadow: {
            type: 'field_colour_hsv_sliders',
            fields: {
              COLOUR: '#ff0000'
            }
          }
        }
      }
    },
    {
      kind: 'block',
      type: 'head_show_expression'
    },
  ],
};