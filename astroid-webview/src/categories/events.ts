// src/categories/events.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';

Blockly.defineBlocksWithJsonArray([
  {
    "type": "program_start",
    "message0": "When Adventure Starts",
    "nextStatement": null,
    "style": "events_blocks",
    "tooltip": "This block is the starting point for your adventure."
  }
]);

javascriptGenerator.forBlock['program_start'] = function(block, generator) {
  const nextBlock = block.getNextBlock();
  if (nextBlock) {
    return generator.blockToCode(nextBlock);
  }
  return '';
};

export const eventsCategory = {
  kind: 'category',
  name: 'Events',
  categorystyle: 'events_category',
  contents: [
    {
      kind: 'block',
      type: 'program_start'
    },
  ],
};