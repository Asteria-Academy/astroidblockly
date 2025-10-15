import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';

Blockly.defineBlocksWithJsonArray([
  {
    "type": "controls_repeat_ext",
    "message0": "repeat %1 times",
    "args0": [
      {
        "type": "field_number",
        "name": "TIMES",
        "value": 10,
        "min": 0,
        "precision": 1
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
    "style": "logic_blocks",
    "tooltip": "Repeat the enclosed blocks a number of times."
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

export const controlCategory = {
  kind: 'category',
  name: 'Control',
  categorystyle: 'logic_category',
  contents: [
    {
      kind: 'block',
      type: 'controls_repeat_ext'
    },
    // We will add if/else here later
  ],
};