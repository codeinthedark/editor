/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const _ = require("underscore");
const $ = require("gulp-load-plugins")();
const gulp = require("gulp");
const path = require("path");
const rename = require("gulp-rename");
const merge = require("merge-stream");
const deepExtend = require("deep-extend");
const runSequence = require("run-sequence");
const autoprefixer = require("autoprefixer-core");

const webpack = require("webpack");
const WebpackDevServer = require("webpack-dev-server");

//###################
//# CONFIG
//###################

var config = {
  paths: {
    app: "app",
    tmp: ".tmp",
    dist: "dist",
    scripts: "app/scripts",
    styles: "app/styles",
    assets: "app/assets"
  },

  serverPort: 9000,

  webpack() {
    return {
      resolveLoader: {
        moduleDirectories: ["node_modules"]
      },

      output: {
        path: path.join(__dirname, config.paths.tmp),
        filename: "bundle.js"
      },

      resolve: {
        extensions: ["", ".js", ".scss", ".css", ".ttf"],
        alias: {
          "assets": path.join(__dirname, config.paths.assets)
        }
      },

      module: {
        loaders: [
          { test: /\.scss$/, loaders: ["style", "css", "postcss-loader", "sass"] },
          { test: /\.png/, loaders: ["url-loader?mimetype=image/png"] },
          { test: /\.ttf/, loaders: ["url-loader?mimetype=font/ttf"] }
        ]
      },

      postcss: [autoprefixer({ browsers: ["last 2 version"] })]
    };
  },

  webpackEnvs() {
    return {
      development: {
        devtool: "eval",
        debug: true,
        entry: [
          `webpack-dev-server/client?http://0.0.0.0:${config.serverPort}`,
          "webpack/hot/only-dev-server",
          `./${config.paths.scripts}/app`
        ],

        plugins: [
          new webpack.HotModuleReplacementPlugin,
          new webpack.NoErrorsPlugin()
        ]
      },

      distribute: {
        entry: [
          `./${config.paths.scripts}/app`
        ],

        plugins: [
          new webpack.optimize.DedupePlugin(),
          new webpack.optimize.UglifyJsPlugin({
            compressor: { warnings: false }
          })
        ]
      }
    };
  }
};

config = _(config).mapObject(function(val) {
  if (_.isFunction(val)) { return val(); } else { return val; }
});

const webpackers = _(config.webpackEnvs).mapObject(val => webpack(deepExtend({}, config.webpack, val)));

//###################
//# TASKS
//###################

gulp
  .task("copy-assets", function() {
    const assets = gulp
      .src(path.join(config.paths.assets, "**"))
      .pipe(gulp.dest(`${config.paths.tmp}/assets`));


    const instructions = gulp
      .src(path.join(config.paths.app, "index.html"))
      .pipe(gulp.dest(config.paths.tmp));

    return merge(assets, instructions);
}).task("copy-page-files", () => gulp
  .src(path.join(config.paths.assets, "{instructions.html,page.png,result.html,beach.jpg}"))
  .pipe(gulp.dest(path.join(config.paths.dist, "assets")))).task("webpack-dev-server", function(done) {
    const server = new WebpackDevServer(webpackers.development, {
      contentBase: config.paths.tmp,
      hot: true,
      watchDelay: 100,
      noInfo: true
    }
    );

    return server.listen(config.serverPort, "0.0.0.0", function(err) {
      if (err) { throw new $.util.PluginError("webpack-dev-server", err); }
      $.util.log($.util.colors.green(
        `[webpack-dev-server] Server running on http://localhost:${config.serverPort}`)
      );

      return done();
    });
    }).task("build", done => webpackers.distribute.run(function(err, stats) {
  if (err) { throw new $.util.PluginError("webpack:build", err); }
  return done();
})).task("serve", ["copy-assets", "webpack-dev-server"], () => gulp.watch(["app/assets/**"], ["copy-assets"]))

  .task("inline", () => gulp
  .src(`${config.paths.tmp}/index.html`)
  .pipe($.inlineSource())
  .pipe(rename({basename: "editor"}))
  .pipe(gulp.dest(`${config.paths.dist}`))).task("dist", () => runSequence("copy-assets", "build", "inline", "copy-page-files")).task("default", ["serve"]);
