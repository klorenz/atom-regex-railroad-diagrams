#RegexRailroadDiagramView = require './regex-railroad-diagram-view'
{CompositeDisposable, Emitter, Range} = require 'atom'
{debounce} = require "underscore-plus"
RailroadDiagramElement = require "./railroad-diagram-element.coffee"

MATCH_PAIRS = '(': ')', '[': ']', '{': '}', '<': '>'

module.exports =
  regexRailroadDiagramView: null

  activate: (state) ->
    @subscriptions = new CompositeDisposable
    @emitter       = new Emitter

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      @subscriptions.add editor.onDidChangeCursorPosition debounce (=> @checkForRegExp()), 100

    #@subscriptions.add atom.workspace.onDidChangeActivePaneItem =>
      # @element.assertHide()
      #debounce (=> @checkForRegExp()), 100

    @element = (new RailroadDiagramElement).initialize this

  deactivate: ->
    #@regexRailroadDiagramView.destroy()
    @subscriptions.dispose()

  serialize: ->
    #regexRailroadDiagramViewState: @regexRailroadDiagramView.serialize()

  bufferRangeForScope: (editor, scope, position=null) ->
    if position?
      result = editor.displayBuffer.bufferRangeForScopeAtPosition(scope, position)
    else
      result = editor.bufferRangeForScopeAtCursor(scope)
    return result

  getRegexpBufferRange: (editor) ->
    position = editor.getCursorBufferPosition()
    flavour = editor.scopeDescriptorForBufferPosition(position).scopes[0]
    range = @bufferRangeForScope(editor, '.raw-regex')

    unless range
      range = @bufferRangeForScope(editor, '.unicode-raw-regex')

    unless range
      range = @bufferRangeForScope(editor, '.regexp')
      # flavour = 'regexp'

    unless range
      return [null, null]

    if editor.bufferRangeForScopeAtCursor('source.ruby')
      punctuationSelector = '.punctuation.section.regexp'
    else if editor.bufferRangeForScopeAtCursor('source.python')
      punctuationSelector = '.punctuation.definition.string'
    else if editor.bufferRangeForScopeAtCursor('source.coffee')
      punctuationSelector = '.punctuation.definition.string'
    else
      punctuationSelector = '.punctuation'

    # skip 'r' in strings like r'''...'''
    while startRange = @bufferRangeForScope editor, '.storage.type.string.python'
      break if range.start.isEqual startRange.end
      range = new Range startRange.end, range.end

    # # skip punctuation
    # while startRange = @bufferRangeForScope editor, punctuationSelector, range.start
    #   break if range.end.isEqual endRange.start
    #   range = new Range range.start, endRange.start
    #
    # while endRange = @bufferRangeForScope editor, punctuationSelector, [range.end.row, range.end.column-1]
    #   break if range.end.isEqual endRange.start
    #   range = new Range range.start, endRange.start

    return [range, flavour]

  cleanRegex: (regex, flavour) ->
    opts = []

    console.log "regex", regex, "flavour", flavour

    debugger

    if m = (flavour.match(/php/) and regex.match(/^(["'])\/(.*)\/(\w*)\1$/))
      [regex, opts] = m[2..]
    else if m = (flavour.match(/python/) and regex.match(/^u?r('''|"""|"|')(.*)\1$/))
      regex = m[2]
    else if m = (flavour.match(/coffee/) and regex.match(/^\/\/\/(.*)\/\/\/(\w*)/))
      [regex, opts] = m[1..]
    else if m = (flavour.match(/ruby/) and regex.match(/^%r(.)(.*)(\W)(\w*)$/))
      [open, text, close, opts] = m[1..]
      expectedClose = MATCH_PAIRS[open] or open
      if close != expectedClose
        text = text + close + m[4]
        close = expecctedClose
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
        close = expecctedClose
      regexForEscaped = new RegExp("\\\\(#{open}|#{close})", 'g')
      regex = text.replace(/\//, '\\/').replace(regexForEscaped, '$1')
    else if m = regex.match(/^\/(.*)\/(\w*)$/)
      [regex, opts] = m[1..]

    console.log "regex", regex, "flavour", flavour, "opts", opts

    return [regex, opts]

  checkForRegExp: ->
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
      @element.showDiagram regex, flavour

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
