require "../styles/index"

_ = require "underscore"
$ = require "jquery"

ace = require "brace"
require "brace/mode/html"
require "brace/theme/vibrant_ink"
require "brace/ext/searchbox"

class App
  POWER_MODE_ACTIVATION_THRESHOLD: 200
  STREAK_TIMEOUT: 10 * 1000

  MAX_PARTICLES: 500
  PARTICLE_NUM_RANGE: [5..12]
  PARTICLE_GRAVITY: 0.075
  PARTICLE_SIZE: 8
  PARTICLE_ALPHA_FADEOUT: 0.96
  PARTICLE_VELOCITY_RANGE:
    x: [-2.5, 2.5]
    y: [-7, -3.5]

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
    "comment": [0, 255, 121]
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
    @$nameTag = $ ".name-tag"
    @$result = $ ".result"
    @$editor = $ "#editor"
    @canvas = @setupCanvas()
    @canvasContext = @canvas.getContext "2d"
    @$finish = $ ".finish-button"

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

    $(".instructions-container, .instructions-button").on "click", @onClickInstructions
    @$reference.on "click", @onClickReference
    @$finish.on "click", @onClickFinish
    @$nameTag.on "click", => @getName true

    @getName()

    window.requestAnimationFrame? @onFrame

  setupAce: ->
    editor = ace.edit "editor"

    editor.setShowPrintMargin false
    editor.setHighlightActiveLine false
    editor.setFontSize 20
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

  getName: (forceUpdate) ->
    name = (not forceUpdate and localStorage["name"]) || prompt "What's your name?"
    localStorage["name"] = name
    @$nameTag.text(name) if name

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
    top -= @editor.renderer.scrollTop
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
      @canvasContext.fillRect(
        Math.round(particle.x - @PARTICLE_SIZE / 2)
        Math.round(particle.y - @PARTICLE_SIZE / 2)
        @PARTICLE_SIZE
        @PARTICLE_SIZE
      )

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

  onClickInstructions: =>
    $("body").toggleClass "show-instructions"
    @editor.focus() unless $("body").hasClass "show-instructions"

  onClickReference: =>
    @$reference.toggleClass "active"
    @editor.focus() unless @$reference.hasClass("active")

  onClickFinish: =>
    confirm = prompt "
      This will show the results of your code. Doing this before the round is over
      WILL DISQUALIFY YOU. Are you sure you want to proceed? Type \"yes\" to confirm.
    "

    if confirm?.toLowerCase() is "yes"
      @$result[0].contentWindow.postMessage(@editor.getValue(), "*")
      @$result.show()

  onChange: (e) =>
    @debouncedSaveContent()
    insertTextAction = e.data.action is "insertText"
    if insertTextAction
      @increaseStreak()
      @debouncedEndStreak()

    @throttledShake()

    range = e.data.range
    pos = if insertTextAction then range.end else range.start

    token = @editor.session.getTokenAt pos.row, pos.column

    _.defer =>
      @throttledSpawnParticles(token.type) if token

$ -> new App
