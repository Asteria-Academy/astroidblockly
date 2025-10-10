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
  size: 11,
};

// --- COMPONENT STYLES ---
const darkComponentStyles: Blockly.Theme.ComponentStyle = {
  workspaceBackgroundColour: '#0B1433',
  toolboxBackgroundColour: '#122A4D',
  toolboxForegroundColour: '#E0E0E0',
  flyoutBackgroundColour: '#1A244A',
  flyoutForegroundColour: '#E0E0E0',
  flyoutOpacity: 0.98,
  scrollbarColour: '#454A5A',
  insertionMarkerColour: '#A4F2FF',
  insertionMarkerOpacity: 0.4,
};

// --- CATEGORY AND BLOCK STYLES ---
const categoryColors = {
  events: '#f59e0b',
  motors: '#0D65D9',
  motion: '#00A1AA',
  looks: '#8057E3',
  audio: '#CF2292',
  control: '#F46718',
  operators: '#40BF4A',
  sensors: '#0891B2',
  variables: '#FF8C1A',
  text: '#0EA5E9', 
  functions: '#D94575',
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

const AstroidDarkTheme = new Blockly.Theme('astroid-dark-theme', blockStyles, categoryStyles, darkComponentStyles);
AstroidDarkTheme.fontStyle = fontStyle;

export function getAstroidTheme(): Blockly.Theme {
  return AstroidDarkTheme;
}