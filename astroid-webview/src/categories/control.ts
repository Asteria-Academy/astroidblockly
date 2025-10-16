import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';

Blockly.defineBlocksWithJsonArray([
  {
    "type": "controls_repeat_ext",
    "message0": "repeat %1 times",
    "args0": [
      {
        "type": "input_value",
        "name": "TIMES",
        "check": "Number",
        "shadow": {
          "type": "math_number",
          "fields": {
            "NUM": 10
          }
        }
      }
    ],
    "message1": "do %1",
    "args1": [
      {
        "type": "input_statement",
        "name": "DO"
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "control_blocks",
    "tooltip": "Repeat the enclosed blocks a number of times."
  },
  {
    "type": "controls_wait",
    "message0": "wait %1 seconds",
    "args0": [
      {
        "type": "field_number",
        "name": "DURATION",
        "value": 1,
        "min": 0,
        "precision": 0.1
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "control_blocks",
    "tooltip": "Waits for a specified amount of time before continuing."
  }
]);

javascriptGenerator.forBlock['controls_repeat_ext'] = function(block, generator) {
  const repeats = Number(block.getFieldValue('TIMES'));
  const branch = generator.statementToCode(block, 'DO');
  
  const startLoopCmd = JSON.stringify({
    command: 'META_START_LOOP',
    params: { times: repeats }
  });
  
  const endLoopCmd = JSON.stringify({
    command: 'META_END_LOOP',
    params: {}
  });

  const code = `${startLoopCmd};${branch}${endLoopCmd};`;
  return code;
};

javascriptGenerator.forBlock['controls_wait'] = function(block, _generator) {
  const durationInSeconds = Number(block.getFieldValue('DURATION'));
  const durationInMs = durationInSeconds * 1000;
  
  const waitCmd = JSON.stringify({
    command: 'WAIT',
    params: { duration_ms: durationInMs }
  });

  return `${waitCmd};`;
};

export const controlCategory = {
  kind: 'category',
  name: 'Control',
  categorystyle: 'control_category',
  contents: [
    {
      kind: 'block',
      type: 'controls_repeat_ext'
    },
    {
      kind: 'block',
      type: 'controls_wait'
    },
  ],
};