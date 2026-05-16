const path = require('path');
const { readdirSync } = require('fs');

// Auto-discover all *.test.ts entry points under src/
const entries = readdirSync(path.resolve(__dirname, 'src'))
  .filter((f) => f.endsWith('.test.ts'))
  .reduce((acc, file) => {
    const name = file.replace('.test.ts', '');
    acc[name] = path.resolve(__dirname, 'src', file);
    return acc;
  }, {});

module.exports = {
  mode: 'production',
  entry: entries,
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].js',
    libraryTarget: 'commonjs',
  },
  resolve: {
    extensions: ['.ts', '.js'],
    alias: {
      '@utils': path.resolve(__dirname, 'src/utils'),
      '@types-local': path.resolve(__dirname, 'src/types'),
    },
  },
  module: {
    rules: [
      {
        test: /\.ts$/,
        use: 'babel-loader',
        exclude: /node_modules/,
      },
    ],
  },
  // k6 and its sub-modules must not be bundled — they are provided at runtime.
  externals: /^(k6|https?:\/\/)(\/.*)?/,
  target: 'web',
  optimization: {
    minimize: false,
  },
  stats: {
    colors: true,
  },
};
