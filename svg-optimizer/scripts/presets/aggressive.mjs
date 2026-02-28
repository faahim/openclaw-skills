export default {
  multipass: true,
  plugins: [
    'preset-default',
    'removeDimensions',
    'sortAttrs',
    'removeOffCanvasPaths',
    {
      name: 'removeAttrs',
      params: { attrs: '(data-.*|class|style)' }
    },
    {
      name: 'convertPathData',
      params: { floatPrecision: 1 }
    }
  ]
};
