require "../styles/index"

_ = require "underscore"
$ = require "jquery"

ace = require "brace"
require "brace/mode/html"
require "brace/theme/vibrant_ink"
require "brace/ext/searchbox"

class App
  POWER_MODE_ACTIVATION_THRESHOLD: 250
  STREAK_TIMEOUT: 10 * 1000

  MAX_PARTICLES: 500
  PARTICLE_NUM_RANGE: [5..12]
  PARTICLE_GRAVITY: 0.075
  PARTICLE_ALPHA_FADEOUT: 0.96
  PARTICLE_VELOCITY_RANGE:
    x: [-1, 1]
    y: [-3.5, -1.5]

  PARTICLE_COLORS:
    "text": [255, 255, 255]
    "text.xml": [255, 255, 255]
    "keyword": [0, 221, 255]
    "variable": [0, 221, 255]
    "meta.tag.tag-name.xml": [0, 221, 255]
    "keyword.operator.attribute-equals.xml": [0, 221, 255]
    "constant": [249, 255, 0]
    "constant.numeric": [249, 255, 0]
    "support.constant": [249, 255, 0]
    "string.attribute-value.xml": [249, 255, 0]
    "string.unquoted.attribute-value.html": [249, 255, 0]
    "entity.other.attribute-name.xml": [129, 148, 244]
    "comment.xml": [0, 255, 121]

  EXCLAMATION_EVERY: 10
  EXCLAMATIONS: ["Super!", "Radical!", "Fantastic!", "Great!", "OMG",
  "Whoah!", ":O", "Nice!", "Splendid!", "Wild!", "Grand!", "Impressive!",
  "Stupendous!", "Extreme!", "Awesome!"]

  currentStreak: 0
  powerMode: false
  particles: []
  particlePointer: 0
  lastDraw: 0

  constructor: ->
    @$streakCounter = $ ".streak-container .counter"
    @$streakBar = $ ".streak-container .bar"
    @$exclamations = $ ".streak-container .exclamations"
    @$reference = $ ".reference-screenshot-container"
    @$editor = $ "#editor"
    @canvas = @setupCanvas()
    @canvasContext = @canvas.getContext "2d"
    @$download = $ ".download-button"

    @$body = $ "body"

    @debouncedSaveContent = _.debounce @saveContent, 300
    @debouncedEndStreak = _.debounce @endStreak, @STREAK_TIMEOUT
    @throttledShake = _.throttle @shake, 100, trailing: false
    @throttledSpawnParticles = _.throttle @spawnParticles, 25, trailing: false

    @editor = @setupAce()
    @loadContent()
    @editor.focus()

    @editor.getSession().on "change", @onChange
    $(window).on "beforeunload", -> "Hold your horses!"

    $(".instructions-container, .instructions-button").on "click", ->
      $("body").toggleClass "show-instructions"

    @$reference.on "click", => @$reference.toggleClass "active"
    @$download.on "click", @onClickDownload

    window.requestAnimationFrame? @onFrame

  setupAce: ->
    editor = ace.edit "editor"

    editor.setShowPrintMargin false
    editor.setHighlightActiveLine false
    editor.setTheme "ace/theme/vibrant_ink"
    editor.getSession().setMode "ace/mode/html"
    editor.session.setOption "useWorker", false
    editor.session.setFoldStyle "manual"
    editor.$blockScrolling = Infinity

    editor

  setupCanvas: ->
    canvas = $(".canvas-overlay")[0]
    canvas.width = window.innerWidth
    canvas.height = window.innerHeight
    canvas

  loadContent: ->
    return unless (content = localStorage["content"])
    @editor.setValue content, -1

  saveContent: =>
    localStorage["content"] = @editor.getValue()

  onFrame: (time) =>
    @drawParticles time - @lastDraw
    @lastDraw = time
    window.requestAnimationFrame? @onFrame

  increaseStreak: ->
    @currentStreak++
    @showExclamation() if @currentStreak > 0 and @currentStreak % @EXCLAMATION_EVERY is 0

    if @currentStreak >= @POWER_MODE_ACTIVATION_THRESHOLD and not @powerMode
      @activatePowerMode()

    @refreshStreakBar()

    @renderStreak()

  endStreak: ->
    @currentStreak = 0
    @renderStreak()
    @deactivatePowerMode()

  renderStreak: ->
    @$streakCounter
      .text @currentStreak
      .removeClass "bump"

    _.defer =>
      @$streakCounter.addClass "bump"

  refreshStreakBar: ->
    @$streakBar.css
      "webkit-transform": "scaleX(1)"
      "transform": "scaleX(1)"
      "transition": "none"

    _.defer =>
      @$streakBar.css
        "webkit-transform": ""
        "transform": ""
        "transition": "all #{@STREAK_TIMEOUT}ms linear"

  showExclamation: ->
    $exclamation = $("<span>")
      .addClass "exclamation"
      .text _.sample(@EXCLAMATIONS)

    @$exclamations.prepend $exclamation
    setTimeout ->
      $exclamation.remove()
    , 3000

  getCursorPosition: ->
    {left, top} = @editor.renderer.$cursorLayer.getPixelPosition()
    left += @editor.renderer.gutterWidth + 4
    {x: left, y: top}

  spawnParticles: (type) ->
    return unless @powerMode

    {x, y} = @getCursorPosition()
    numParticles = _(@PARTICLE_NUM_RANGE).sample()
    color = @getParticleColor type
    _(numParticles).times =>
      @particles[@particlePointer] = @createParticle x, y, color
      @particlePointer = (@particlePointer + 1) % @MAX_PARTICLES

  getParticleColor: (type) ->
    @PARTICLE_COLORS[type] or [255, 255, 255]

  createParticle: (x, y, color) ->
    x: x
    y: y + 10
    alpha: 1
    color: color
    velocity:
      x: @PARTICLE_VELOCITY_RANGE.x[0] + Math.random() *
        (@PARTICLE_VELOCITY_RANGE.x[1] - @PARTICLE_VELOCITY_RANGE.x[0])
      y: @PARTICLE_VELOCITY_RANGE.y[0] + Math.random() *
        (@PARTICLE_VELOCITY_RANGE.y[1] - @PARTICLE_VELOCITY_RANGE.y[0])

  drawParticles: (timeDelta) =>
    @canvasContext.clearRect 0, 0, @canvas.width, @canvas.height

    for particle in @particles
      continue if particle.alpha <= 0.1

      particle.velocity.y += @PARTICLE_GRAVITY
      particle.x += particle.velocity.x
      particle.y += particle.velocity.y
      particle.alpha *= @PARTICLE_ALPHA_FADEOUT

      @canvasContext.fillStyle = "rgba(#{particle.color.join ", "}, #{particle.alpha})"
      @canvasContext.fillRect Math.round(particle.x - 1), Math.round(particle.y - 1), 3, 3

  shake: ->
    return unless @powerMode

    intensity = 1 + 2 * Math.random() * Math.floor(
      (@currentStreak - @POWER_MODE_ACTIVATION_THRESHOLD) / 100
    )
    x = intensity * (if Math.random() > 0.5 then -1 else 1)
    y = intensity * (if Math.random() > 0.5 then -1 else 1)

    @$editor.css "margin", "#{y}px #{x}px"

    setTimeout =>
      @$editor.css "margin", ""
    , 75

  activatePowerMode: =>
    @powerMode = true
    @$body.addClass "power-mode"

  deactivatePowerMode: =>
    @powerMode = false
    @$body.removeClass "power-mode"

  onClickDownload: =>
    $a = $("<a>")
      .attr "href", window.URL.createObjectURL(new Blob([@editor.getValue()], {type: "text/txt"}))
      .attr "download", "design.html"
      .appendTo "body"

    $a[0].click()

    $a.remove()

  onChange: (e) =>
    @debouncedSaveContent()
    if e.data.action is "insertText"
      @increaseStreak()
      @debouncedEndStreak()

    @throttledShake()

    pos = if e.data.action is "insertText"
      e.data.range.end
    else
      e.data.range.start

    token = @editor.session.getTokenAt pos.row, pos.column

    _.defer =>
      @throttledSpawnParticles(token.type) if token

$ -> new App