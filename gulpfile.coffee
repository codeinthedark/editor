_ = require "underscore"
$ = require("gulp-load-plugins")()
gulp = require "gulp"
path = require "path"
rename = require "gulp-rename"
merge = require "merge-stream"
deepExtend = require "deep-extend"
runSequence = require "run-sequence"
autoprefixer = require "autoprefixer-core"

webpack = require "webpack"
WebpackDevServer = require "webpack-dev-server"

####################
## CONFIG
####################

config =
  paths:
    app: "app"
    tmp: ".tmp"
    dist: "dist"
    scripts: "app/scripts"
    styles: "app/styles"
    assets: "app/assets"

  serverPort: 9000

  webpack: ->
    resolveLoader:
      moduleDirectories: ["node_modules"]

    output:
      path: path.join __dirname, config.paths.tmp
      filename: "bundle.js"

    resolve:
      extensions: ["", ".js", ".coffee", ".scss", ".css", ".ttf"]
      alias:
        "assets": path.join __dirname, config.paths.assets

    module:
      loaders: [
        { test: /\.scss$/, loaders: ["style", "css", "postcss-loader", "sass"] }
        { test: /\.coffee$/, loaders: ["coffee"] }
        { test: /\.png/, loaders: ["url-loader?mimetype=image/png"] }
        { test: /\.ttf/, loaders: ["url-loader?mimetype=font/ttf"] }
      ]

    postcss: [autoprefixer({ browsers: ["last 2 version"] })]

  webpackEnvs: ->
    development:
      devtool: "eval"
      debug: true
      entry: [
        "webpack-dev-server/client?http://0.0.0.0:#{config.serverPort}"
        "webpack/hot/only-dev-server"
        "./#{config.paths.scripts}/app"
      ]

      plugins: [
        new webpack.HotModuleReplacementPlugin
        new webpack.NoErrorsPlugin()
      ]

    distribute:
      entry: [
        "./#{config.paths.scripts}/app"
      ]

      plugins: [
        new webpack.optimize.DedupePlugin()
        new webpack.optimize.UglifyJsPlugin(
          compressor: { warnings: false }
        )
      ]

config = _(config).mapObject (val) ->
  if _.isFunction(val) then val() else val

webpackers = _(config.webpackEnvs).mapObject (val) ->
  webpack deepExtend({}, config.webpack, val)

####################
## TASKS
####################

gulp
  .task "copy-assets", ->
    assets = gulp
      .src path.join(config.paths.assets, "**")
      .pipe gulp.dest("#{config.paths.tmp}/assets")


    instructions = gulp
      .src path.join(config.paths.app, "index.html")
      .pipe gulp.dest(config.paths.tmp)

    merge assets, instructions

  .task "copy-page-files", ->
    gulp
      .src path.join(config.paths.assets, "{instructions.html,page.png,result.html,beach.jpg}")
      .pipe gulp.dest(path.join config.paths.dist, "assets")

  .task "webpack-dev-server", (done) ->
    server = new WebpackDevServer webpackers.development,
      contentBase: config.paths.tmp
      hot: true
      watchDelay: 100
      noInfo: true

    server.listen config.serverPort, "0.0.0.0", (err) ->
      throw new $.util.PluginError("webpack-dev-server", err) if err
      $.util.log $.util.colors.green(
        "[webpack-dev-server] Server running on http://localhost:#{config.serverPort}")

      done()

  .task "build", (done) ->
    webpackers.distribute.run (err, stats) ->
      throw new $.util.PluginError("webpack:build", err) if err
      done()

  .task "serve", ["copy-assets", "webpack-dev-server"], ->
    gulp.watch ["app/assets/**"], ["copy-assets"]

  .task "inline", ->
    gulp
      .src "#{config.paths.tmp}/index.html"
      .pipe $.inlineSource()
      .pipe rename(basename: "editor")
      .pipe gulp.dest("#{config.paths.dist}")

  .task "dist", ->
    runSequence "copy-assets", "build", "inline", "copy-page-files"

  .task "default", ["serve"]
