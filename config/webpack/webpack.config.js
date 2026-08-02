const { generateWebpackConfig } = require('shakapacker')

module.exports = generateWebpackConfig({
  resolve: {
    extensions: ['.css', '.scss']
  },
  performance: {
    maxEntrypointSize: 0
  }
})
