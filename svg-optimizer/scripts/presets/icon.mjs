export default {
  multipass: true,
  plugins: [
    'preset-default',
    'removeDimensions',
    'sortAttrs',
    'removeXMLNS',
    {
      name: 'addAttributesToSVGElement',
      params: {
        attributes: [{ fill: 'currentColor' }]
      }
    }
  ]
};
