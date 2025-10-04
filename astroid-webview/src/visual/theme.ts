// src/visual/theme.ts

import * as Blockly from 'blockly/core';

// --- Helper Functions to adjust colors ---
function adjust(hex: string, amount: number): string {
  const color = Blockly.utils.colour.hexToRgb(hex);
  const a = Math.max(-1, Math.min(1, amount));
  const blend = (c: number) => {
    let v: number;
    if (a >= 0) {
      v = c + (255 - c) * a;
    } else {
      v = c * (1 + a);
    }
    return Math.round(Math.min(255, Math.max(0, v)));
  };
  return Blockly.utils.colour.rgbToHex(blend(color[0]), blend(color[1]), blend(color[2]));
}

// --- FONT STYLE ---
const fontStyle: Blockly.Theme.FontStyle = {
  family: '"Poppins", "Verdana", "Segoe UI", Helvetica, sans-serif',
  weight: '500',
  size: 12,
};

// --- COMPONENT STYLES ---
const componentStyles: Blockly.Theme.ComponentStyle = {
  workspaceBackgroundColour: '#f9fafb',
  toolboxBackgroundColour: '#ffffff',
  toolboxForegroundColour: '#1e293b',
  flyoutBackgroundColour: '#f1f5f9',
  flyoutForegroundColour: '#1e293b',
  flyoutOpacity: 0.97,
  scrollbarColour: '#cbd5e1',
  insertionMarkerColour: '#F46718',
  insertionMarkerOpacity: 0.35,
};

// --- CATEGORY AND BLOCK STYLES ---
const categoryColors = {
  events: '#f59e0b',
  motors: '#0D65D9',      // Drive system
  motion: '#00A1AA',      // For servos/neck
  looks: '#8057E3',       // For LED/LCD
  control: '#F46718',
  operators: '#40BF4A',
  // Ensure text blocks have a defined style referenced by styleMap ('text_blocks').
  text: '#0EA5E9',
  variables: '#FF8C1A',
  functions: '#D94575',   // For gripper/mechanisms
};

const blockStyles: { [key: string]: Blockly.Theme.BlockStyle } = {};
const categoryStyles: { [key: string]: Blockly.Theme.CategoryStyle } = {};

for (const key in categoryColors) {
    const primary = categoryColors[key as keyof typeof categoryColors];
    blockStyles[`${key}_blocks`] = {
        colourPrimary: primary,
        colourSecondary: adjust(primary, 0.15),
        colourTertiary: adjust(primary, -0.15),
        hat: '',
    };
    categoryStyles[`${key}_category`] = { colour: primary };
}
blockStyles.events_blocks.hat = 'cap';

const AstroidTheme = new Blockly.Theme('astroid-theme', blockStyles, categoryStyles, componentStyles);
AstroidTheme.fontStyle = fontStyle;

// export function getAstroidTheme(isDark: boolean = false): Blockly.Theme {
export function getAstroidTheme(): Blockly.Theme {
  // For now, we only have a light theme.
  // We can easily add a dark theme variant later by creating darkComponentStyles.
  return AstroidTheme;
}

// Provide standard style keys used by built-in blocks so they map to our palette
// without overriding any block init logic.
const cloneStyle = (from: string, to: string) => {
  if (blockStyles[from]) {
    blockStyles[to] = { ...blockStyles[from] };
  }
};

cloneStyle('operators_blocks', 'math_blocks');
cloneStyle('operators_blocks', 'logic_blocks');
cloneStyle('operators_blocks', 'list_blocks');
cloneStyle('control_blocks', 'loop_blocks');
cloneStyle('looks_blocks', 'colour_blocks');
cloneStyle('functions_blocks', 'procedure_blocks');
// variables/text styles already exist as variables_blocks/text_blocks

export function applyAstroidThemeStyles() {
  // No-op. Built-in blocks will use the style keys above from the theme.
}