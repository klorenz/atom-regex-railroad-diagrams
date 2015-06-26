{Regex2RailRoadDiagram} = require './regex-to-railroad'
{$$, View, $} = require "atom-space-pen-views"
{Range} = require 'atom'

module.exports =
class RegexRailroadDiagramView extends View
  MATCH_PAIRS = '(': ')', '[': ']', '{': '}', '<': '>'

  @content: ->
    @div class: 'regex-railroad-diagram'

  initialize: (serializeState) ->
    #console.log "hello from rr"

    @isVisible    = false
    @currentRegex = null
    @currentEditor = null

    #@view.command "regex-railroad-diagram:toggle", => @toggle()
    @view = atom.views.getView(atom.workspace)
    @spView = $(@view)
    #@view = atom.views.getView(atom.workspace).__spacePenView


    atom.workspace.observeTextEditors (editor) =>
      editor.onDidChangeCursorPosition (event) =>
        @updateRailRoadDiagram()

      editor.onDidDestroy =>
        if @currentEditor is editor and @currentRegex
          @hideRailRoadDiagram()


#    @view.on 'cursor:moved', @updateRailRoadDiagram

  bufferRangeForScope: (scope, position=null) ->
    editor = @currentEditor
    if position?
      result = editor.displayBuffer.bufferRangeForScopeAtPosition(scope, position)
    else
      result = editor.bufferRangeForScopeAtCursor(scope)
    return result

  regexBufferRange: () ->
    # python uses raw-regex (must be before other, because python grammar
    # also uses regexp for char classes)
    flavour = "python"

    range = @bufferRangeForScope(".raw-regex")

    unless range
      range = @bufferRangeForScope(".unicode-raw-regex")

    unless range
      # usually somewhere there is .regexp in scope name
      range = @bufferRangeForScope(".regexp")
      flavour = "regexp"

    if range
      # skip 'r' in python strings like r'''...'''
      while startRange = @bufferRangeForScope(".storage.type.string.python", range.start)
        break if range.start.isEqual startRange.end
        range = new Range(startRange.end, range.end)

      # skip punctuation
      while startRange = @bufferRangeForScope(".punctuation", range.start)
        #debugger
        break if range.start.isEqual startRange.end
        range = new Range(startRange.end, range.end)

      #console.log("range.end: #{range.end}")

#      debugger
      while endRange = @bufferRangeForScope(".punctuation", [range.end.row, range.end.column - 1])
        #console.log("endRange: #{endRange}")

        break if range.end.isEqual endRange.start
        range = new Range(range.start, endRange.start)
        #console.log("_range: #{range}")

    return [range, flavour]


  updateRailRoadDiagram: () ->
    editor = atom.workspace.getActiveTextEditor()
    return if not editor?

    @currentEditor = editor

    [range, flavour] = @regexBufferRange()

    #console.log "cursor moved", range
    if not range
      if @isVisible
        @hideRailRoadDiagram()
        @currentRegex = null
    else
      text = editor.getTextInBufferRange(range)
      #console.log "regex text 1", text
      #console.log text
      text = text.replace(/^\s+/, "").replace(/\s+$/, "")

      #console.log "regex text 2", text
      # special case, maybe we get a comment, but it might be already
      # marked as regex by language grammar, although it might result in
      # a comment
      if text.length == 1 and text == "/"
        return

      # php has regexp strings (including "")
      if editor.bufferRangeForScopeAtCursor(".php")
        m = /^"\/(.*)\/\w*"$/.exec(text)
        if m?
          text = m[1]
        else
          m = /^'\/(.*)\/\w*'$/.exec(text)
          text = m[1] if m?

      else if editor.bufferRangeForScopeAtCursor("source.ruby")
        m = /^%r(.)(.*)(\W)(\w*)$/.exec(text)
        if m?
          text = m[2]
          [open, close] = [m[1], m[3]]
          expectedClose = MATCH_PAIRS[open] || open
          if close != expectedClose
            # there is no matching pair, use whole remaining string as regex
            text = text + close + m[4]
            close = expectedClose
          regexForEscaped = new RegExp("\\\\(#{open}|#{close})", 'g')
          text = text.replace(/\//g, '\\/').replace(regexForEscaped, '$1')
        else
          m = /^\/(.*)\/\w*$/.exec(text)
          if m?
            text = m[1]

      else
        # python regex
        m = /^u?r('''|"""|"|')(.*)\1$/.exec(text)
        if m?
          text = m[2]

        m = /^\/\/\/(.*)\/\/\/\w*$/.exec(text)
        if m?
          text = m[1].replace(/\s+/, "")
        else
          m = /^\/(.*)\/\w*$/.exec(text)
          if m?
            text = m[1]

      if not @isVisible or @currentRegex != text
        @spView.find('div.error-message').remove()
        try
          @showRailRoadDiagram(text, flavour)
        catch error
          #console.log error
          if not @isVisible
            @showRailRoadDiagram("", flavour)

          sp = " ".repeat(error.offset)

          @append $$ ->
            @div class: "error-message", =>
              @pre "#{text}\n#{sp}^\n#{sp}#{error.message}", class: "text-error"

    @currentRegex = text

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @detach()

  getRegexScope: (scope) ->
    scopeName = []
    for name in scope
      scopeName.push name

      if /^string\.regexp/.test name
        scopeName

    false

  showRailRoadDiagram: (regex, flavour) ->
    rr = @spView.find '.regex-railroad-diagram'

    if not rr.length
      # create current diff
      @hide()

      # append to "panes"
      v = atom.views.getView(atom.workspace.getActivePane())
      $(v).parents('.panes').eq(0).after(@)

    @children().remove()
    Regex2RailRoadDiagram(regex, @.get(0), flavour: flavour)

    @show()
    @isVisible = true

  hideRailRoadDiagram: () ->
    @hide()
    @isVisible = false

    # isRegex = false
    # for scope in scopes
    #   if /^string.regexp/.test scope
    #     isRegex = true
    #     break
    #

  toggle: ->
    #console.log "RegexRailroadDiagramView was toggled!"

    statusBar = @spView.find('.status-bar')

    if statusBar.length > 0
      @insertBefore(statusBar)
    else
      atom.workspace.getActivePane().append(@)

    Diagram(
        Choice(0, Skip(), '-'),
        Choice(0, NonTerminal('name-start char'), NonTerminal('escape')),
        ZeroOrMore(
                Choice(0, NonTerminal('name char'), NonTerminal('escape')))
    ).addTo(@.get(0))

    @
