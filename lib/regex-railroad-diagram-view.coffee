{View, $$} = require 'atom'
{Regex2RailRoadDiagram} = require './regex-to-railroad'

module.exports =
class RegexRailroadDiagramView extends View
  @content: ->
    @div class: 'regex-railroad-diagram'

  initialize: (serializeState) ->
    #console.log "hello from rr"

    @isVisible    = false
    @currentRegex = null
    @currentEditor = null

    #@view.command "regex-railroad-diagram:toggle", => @toggle()
    @view = atom.views.getView(atom.workspace).__spacePenView

    atom.workspace.observeTextEditors (editor) =>
      editor.onDidChangeCursorPosition (event) =>
        @updateRailRoadDiagram()

      editor.onDidDestroy =>
        if @currentEditor is editor and @currentRegex
          @hideRailRoadDiagram()


#    @view.on 'cursor:moved', @updateRailRoadDiagram


  updateRailRoadDiagram: () =>
    editor = atom.workspace.getActiveEditor()
    return if not editor?

    @currentEditor = editor

    flavour = "python"

    # python uses raw-regex (must be before other, because python grammar
    # also uses regexp for char classes)
    range = editor.bufferRangeForScopeAtCursor(".raw-regex")

    unless range
      range = editor.bufferRangeForScopeAtCursor(".unicode-raw-regex")

    unless range
      # usually somewhere there is .regexp in scope name
      range = editor.bufferRangeForScopeAtCursor(".regexp")
      flavour = "regexp"

    #console.log "cursor moved", range
    if not range
      if @isVisible
        @hideRailRoadDiagram()
        @currentRegex = null
    else
      text = editor.getTextInBufferRange(range)
      #console.log text
      text = text.replace(/^\s+/, "").replace(/\s+$/, "")

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
        @.find('div.error-message').remove()
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
    rr = @view.find '.regex-railroad-diagram'
    if not rr.length
      # create current diff
      @hide()

      # append to "panes"
      @view.getActivePaneView().parents('.panes').eq(0).after(@)

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

    statusBar = @view.find('.status-bar')

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
