// src/toolbox.ts
import * as Blockly from 'blockly/core';

import { motorsCategory } from './categories/motors';
import { headCategory } from './categories/head';
import { neckCategory } from './categories/neck';
import { gripperCategory } from './categories/gripper';
import { controlCategory } from './categories/control';
import { operatorsCategory } from './categories/operators';

export function getAstroidToolbox(): Blockly.utils.toolbox.ToolboxDefinition {
  return {
    kind: 'categoryToolbox',
    contents: [
      motorsCategory,
      neckCategory,
      headCategory,
      gripperCategory,
      { kind: 'sep' },
      controlCategory,
      operatorsCategory,
    ],
  };
}