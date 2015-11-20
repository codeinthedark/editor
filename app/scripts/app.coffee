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

  EXCLAMATION_EVERY: 10
  EXCLAMATIONS: ["Super!", "Radical!", "Fantastic!", "Great!", "OMG",
  "Whoah!", ":O", "Nice!", "Splendid!", "Wild!", "Grand!", "Impressive!",
  "Stupendous!", "Extreme!", "Awesome!"]

  currentStreak: 0
  powerMode: false

  constructor: ->
    @$streakCounter = $ ".streak-container .counter"
    @$exclamations = $ ".streak-container .exclamations"
    @$reference = $ ".reference-screenshot-container"
    @$download = $ ".download-button"

    @$body = $ "body"

    @debouncedSaveContent = _.debounce @saveContent, 300
    @debouncedEndStreak = _.debounce @endStreak, @STREAK_TIMEOUT

    @editor = @setupAce()
    @loadContent()
    @editor.focus()

    @editor.getSession().on "change", @onChange
    $(window).on "beforeunload", -> "Hold your horses!"

    $(".instructions-container, .instructions-button").on "click", => $("body").toggleClass "show-instructions"
    @$reference.on "click", => @$reference.toggleClass "active"
    @$download.on "click", @onClickDownload

  setupAce: ->
    editor = ace.edit "editor"

    editor.setShowPrintMargin false
    editor.setHighlightActiveLine false
    editor.setTheme "ace/theme/vibrant_ink"
    editor.getSession().setMode "ace/mode/html"
    editor.session.setOption "useWorker", false
    editor.session.setFoldStyle "manual"

    editor

  loadContent: ->
    return unless (content = localStorage["content"])
    @editor.setValue content, -1

  saveContent: =>
    localStorage["content"] = @editor.getValue()

  increaseStreak: ->
    @currentStreak++
    @showExclamation() if @currentStreak > 0 and @currentStreak % @EXCLAMATION_EVERY is 0

    if @currentStreak >= @POWER_MODE_ACTIVATION_THRESHOLD and not @powerMode
      @activatePowerMode()

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

  showExclamation: ->
    $exclamation = $("<span>")
      .addClass "exclamation"
      .text _.sample(@EXCLAMATIONS)

    @$exclamations.prepend $exclamation
    setTimeout ->
      $exclamation.remove()
    , 3000

  shake: ->
    intensity = -(Math.random() * 5 + 5)
    x = intensity * (Math.random() > 0.5 ? -1 : 1)
    y = intensity * (Math.random() > 0.5 ? -1 : 1)

    translate = "translate3D(#{x}px, #{y}px, 0)"
    @$body.css
      "webkit-transform": translate
      "transform": translate

    setTimeout =>
      @$body.css
        "webkit-transform": "none"
        "transform": "none"
    , 50

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

    @shake() if @powerMode

$ -> new App