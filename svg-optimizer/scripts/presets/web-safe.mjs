export default {
  multipass: true,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          removeTitle: false,
          removeDesc: false,
          removeViewBox: false
        }
      }
    },
    'sortAttrs',
    {
      name: 'removeAttrs',
      params: {
        attrs: [],
        preserveCurrentColor: true
      }
    },
    {
      name: 'removeUnknownsAndDefaults',
      params: {
        keepAriaAttrs: true,
        keepRoleAttr: true
      }
    }
  ]
};
