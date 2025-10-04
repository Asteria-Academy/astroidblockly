// src/categories/control.ts

export const controlCategory = {
  kind: 'category',
  name: 'Control',
  categorystyle: 'control_category',
  contents: [
    { kind: 'block', type: 'controls_if' },
    {
      kind: 'block',
      type: 'controls_repeat_ext',
      inputs: { TIMES: { shadow: { type: 'math_number', fields: { NUM: 10 } } } }
    },
  ],
};