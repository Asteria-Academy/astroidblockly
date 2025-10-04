// src/categories/motors.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator, Order } from 'blockly/javascript';
import { astroidV2 } from '../robotProfiles';

// --- Block Definitions ---
Blockly.defineBlocksWithJsonArray([
  {
    "type": "motor_move_directional",
    "message0": "Move %1 at speed %2",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "DIRECTION",
        "options": [
          ["Forward", "FORWARD"],
          ["Backward", "BACKWARD"]
        ]
      },
      {
        "type": "input_value",
        "name": "SPEED",
        "check": "Number"
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "motors_blocks",
    "tooltip": "Moves the robot forward or backward at a specified speed."
  },
  {
    "type": "motor_turn_directional",
    "message0": "Turn %1",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "DIRECTION",
        "options": [
          ["Left", "LEFT"],
          ["Right", "RIGHT"]
        ]
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "motors_blocks",
    "tooltip": "Turns the robot left or right on the spot."
  },
  {
    "type": "motor_spin_directional",
    "message0": "Spin %1",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "DIRECTION",
        "options": [
          ["Left", "LEFT"],
          ["Right", "RIGHT"]
        ]
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "motors_blocks",
    "tooltip": "Spins the robot continuously left or right."
  },
  {
    "type": "motor_stop",
    "message0": "Stop Moving",
    "previousStatement": null,
    "nextStatement": null,
    "style": "motors_blocks",
    "tooltip": "Stops all robot movement."
  }
]);

// --- Block Generators ---
javascriptGenerator.forBlock['motor_move_directional'] = function(block, generator) {
  const direction = block.getFieldValue('DIRECTION');
  const speed = generator.valueToCode(block, 'SPEED', Order.ATOMIC) || '100';
  
  const command = direction === 'FORWARD' 
    ? astroidV2.commands.moveForward 
    : astroidV2.commands.moveBackward;

  const commandObj = {
    command: command,
    params: {
      speed: parseInt(speed, 10)
    }
  };
  return JSON.stringify(commandObj) + ';';
};

javascriptGenerator.forBlock['motor_turn_directional'] = function(block, _generator) {
  const direction = block.getFieldValue('DIRECTION');
  
  const command = direction === 'LEFT'
    ? astroidV2.commands.turnLeft
    : astroidV2.commands.turnRight;
    
  const commandObj = {
    command: command,
    params: {}
  };
  return JSON.stringify(commandObj) + ';';
};

javascriptGenerator.forBlock['motor_spin_directional'] = function(block, _generator) {
  const direction = block.getFieldValue('DIRECTION');
  
  const command = direction === 'LEFT'
    ? astroidV2.commands.spinLeft
    : astroidV2.commands.spinRight;

  const commandObj = {
    command: command,
    params: {}
  };
  return JSON.stringify(commandObj) + ';';
};

javascriptGenerator.forBlock['motor_stop'] = function(_block, _generator) {
  const commandObj = {
    command: astroidV2.commands.stop,
    params: {}
  };
  return JSON.stringify(commandObj) + ';';
};

export const motorsCategory = {
  kind: 'category',
  name: 'Drive',
  categorystyle: 'motors_category',
  contents: [
    {
      kind: 'block',
      type: 'motor_move_directional',
      inputs: {
        SPEED: {
          shadow: {
            type: 'math_number',
            fields: { NUM: 100 }
          }
        }
      }
    },
    {
      kind: 'block',
      type: 'motor_turn_directional'
    },
    {
      kind: 'block',
      type: 'motor_spin_directional'
    },
    {
      kind: 'block',
      type: 'motor_stop'
    },
  ],
};