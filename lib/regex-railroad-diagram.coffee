#RegexRailroadDiagramView = require './regex-railroad-diagram-view'
{CompositeDisposable, Emitter, Range} = require 'atom'
{debounce} = require "underscore-plus"
RailroadDiagramElement = require "./railroad-diagram-element.coffee"

MATCH_PAIRS = '(': ')', '[': ']', '{': '}', '<': '>'

issue58 = true

module.exports =
  regexRailroadDiagramView: null

  config:
    enabled:
      type: "boolean"
      default: true

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter       = new Emitter

    @element = (new RailroadDiagramElement).initialize this

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      @subscriptions.add editor.onDidChangeCursorPosition debounce (=> @checkForRegExp()), 100

    if atom.config.get('regex-railroad-diagram.enabled')
      @addDisableCommand()
    else
      @addEnableCommand()


  addDisableCommand: ->
    @cur_cmd = atom.commands.add "atom-workspace", "regex-railroad-diagram:disable", =>
      @cur_cmd.dispose()
      atom.config.set('regex-railroad-diagram.enabled', false)
      @addEnableCommand()
      @checkForRegExp()

  addEnableCommand: ->
    @cur_cmd = atom.commands.add "atom-workspace", "regex-railroad-diagram:enable", =>
      @cur_cmd.dispose()
      atom.config.set('regex-railroad-diagram.enabled', true)
      @addDisableCommand()
      @checkForRegExp()

  deactivate: ->
    #@regexRailroadDiagramView.destroy()
    @subscriptions.dispose()

  serialize: ->
    #regexRailroadDiagramViewState: @regexRailroadDiagramView.serialize()

  bufferRangeForScope: (editor, scope, position=null) ->
    unless issue58
      if position?
        result = editor.bufferRangeForScopeAtPosition(scope, position)
      else
        result = editor.bufferRangeForScopeAtCursor(scope)
      return result

    # here follows a workaround for fixing #58, till bufferRangeForScopeAtCursor
    # delivers correct address
    #

    tabLength = editor.getTabLength()

    unless position?
      position = editor.getCursorBufferPosition().copy()

    lineStart = [[position.row, 0], [position.row, position.column]]

    if m = editor.getTextInBufferRange(lineStart).match(/\t/g)
      startTabs = m.length
    else
      startTabs = 0

    # shift the position a little, such that als in case of tabs in beginning
    # start of regex is recognized as regex
    if startTabs
      position.column = position.column - startTabs + startTabs*tabLength

    result = editor.bufferRangeForScopeAtPosition(scope, position)
    return result unless result

    # this is usually only one row, but if at some point the range would span
    # multiple rows, this still works

    {start, end} = result

    lineStart = [[end.row, 0], [end.row, end.column]]
    if m = editor.getTextInBufferRange(lineStart).match(/\t/g)
      endTabs = m.length
    else
      endTabs = 0

    return new Range(
      [start.row, start.column - startTabs*tabLength + startTabs],
      [end.row, end.column - endTabs*tabLength + endTabs]
      )

  getRegexpBufferRange: (editor) ->
    position = editor.getCursorBufferPosition()
    flavour = editor.scopeDescriptorForBufferPosition(position).scopes[0]
    range = @bufferRangeForScope(editor, '.raw-regex')

    unless range
      range = @bufferRangeForScope(editor, '.unicode-raw-regex')

    unless range
      range = @bufferRangeForScope(editor, '.regexp')

    unless range
      return [null, null]

    return [range, flavour]

  cleanRegex: (regex, flavour) ->
    opts = ""

    #console.log "regex", regex, "flavour", flavour

    if m = (flavour.match(/php/) and regex.match(/^(["'])\/(.*)\/(\w*)\1$/))
      [regex, opts] = m[2..]
    else if m = (flavour.match(/python|julia/) and regex.match(/^u?r('''|"""|"|')(.*)\1$/))
      regex = m[2]
    else if m = (flavour.match(/coffee/) and regex.match(/^\/\/\/(.*)\/\/\/(\w*)/))
      [regex, opts] = m[1..]
    else if m = (flavour.match(/ruby/) and regex.match(/^%r(.)(.*)(\W)(\w*)$/))
      [open, text, close, opts] = m[1..]
      expectedClose = MATCH_PAIRS[open] or open
      if close != expectedClose
        text = text + close + m[4]
        close = expectedClose
      regexForEscaped = new RegExp("\\\\(#{open}|#{close})", 'g')
      regex = text.replace(/\//, '\\/').replace(regexForEscaped, '$1')
    else if m = (flavour.match(/perl/) and (
        regex.match(/^(?:m|qr)(.)(.*)(\1|\W)(\w*)$/) or
        regex.match(/^s(.)(.*)(\1|\W)(?:\1.*\W|.*\1)(\w*)$/)
      ))
      [open, text, close, opts] = m[1..]
      expectedClose = MATCH_PAIRS[open] or open
      if close != expectedClose
        text = text + close + m[4]
        close = expectedClose
      regexForEscaped = new RegExp("\\\\(#{open}|#{close})", 'g')
      regex = text.replace(/\//, '\\/').replace(regexForEscaped, '$1')
    else if m = regex.match(/^\/(.*)\/(\w*)$/)
      [regex, opts] = m[1..]

    #console.log "regex", regex, "flavour", flavour, "opts", opts

    return [regex, opts]

  checkForRegExp: ->
    if not atom.config.get('regex-railroad-diagram.enabled')
      return @element.assertHidden()

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    [range, flavour] = @getRegexpBufferRange editor

    if not range
      @element.assertHidden()
    else
      regex = editor.getTextInBufferRange(range).trim()

      # special case, maybe we get a comment, but it might be already
      # marked as regex by language grammar, although it might result in
      # a comment
      return @element.assertHidden() if regex is '/'

      [regex, options] = @cleanRegex regex, flavour
      @element.showDiagram regex, {flavour, options}

  #   if not range
  #     @emitter.emit 'did-not-find-regexp'
  #   else
  #     @emitter.emit 'did-find-regexp', editor.getTextInBufferRange range
  #
  # onDidNotFindRegexp: (callback) ->
  #   @emitter.on 'did-not-find-regexp', callback
  #
  # onDidFindRegexp: (callback) ->
  #   @emitter.on 'did-find-regexp', callback
