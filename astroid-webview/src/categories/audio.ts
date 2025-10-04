// src/categories/audio.ts

import * as Blockly from 'blockly/core';
import { javascriptGenerator } from 'blockly/javascript';
import { astroidV2 } from '../robotProfiles';

// --- Block Definitions ---
Blockly.defineBlocksWithJsonArray([
  {
    "type": "audio_play_sound",
    "message0": "play sound %1",
    "args0": [
      {
        "type": "field_dropdown",
        "name": "SOUND",
        "options": [
          ["Beep", "BEEP"],
          ["Siren", "SIREN"],
          ["Success", "SUCCESS"],
          ["Error", "ERROR"]
        ]
      }
    ],
    "previousStatement": null,
    "nextStatement": null,
    "style": "sound_blocks",
    "tooltip": "Plays a pre-programmed sound from the robot's speaker."
  },
  {
    "type": "audio_dance",
    "message0": "start dance mode",
    "previousStatement": null,
    "nextStatement": null,
    "style": "sound_blocks",
    "tooltip": "Makes the robot perform a dance routine."
  }
]);

// --- Block Generators ---
javascriptGenerator.forBlock['audio_play_sound'] = function(block, _generator) {
  const sound = block.getFieldValue('SOUND');
  const commandObj = {
    command: astroidV2.commands.playSound,
    params: { sound: sound }
  };
  return JSON.stringify(commandObj) + ';';
};

javascriptGenerator.forBlock['audio_dance'] = function(_block, _generator) {
  const commandObj = {
    command: astroidV2.commands.danceMode,
    params: {}
  };
  return JSON.stringify(commandObj) + ';';
};

// --- Toolbox Definition ---
export const audioCategory = {
  kind: 'category',
  name: 'Audio',
  categorystyle: 'sound_category',
  contents: [
    { kind: 'block', type: 'audio_play_sound' },
    { kind: 'block', type: 'audio_dance' },
  ],
};