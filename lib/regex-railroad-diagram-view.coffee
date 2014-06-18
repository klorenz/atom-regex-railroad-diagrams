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

    #atom.workspaceView.command "regex-railroad-diagram:toggle", => @toggle()
    atom.workspaceView.on 'cursor:moved', @updateRailRoadDiagram

  updateRailRoadDiagram: () =>
    editor = atom.workspace.getActiveEditor()
    return if not editor?
    range = editor.bufferRangeForScopeAtCursor("string.regexp")
    #console.log "cursor moved", range
    if not range
      if @isVisible
        @hideRailRoadDiagram()
        @currentRegex = null
    else
      text = editor.getTextInBufferRange(range)
      #console.log text
      text = text.replace(/^\s+/, "").replace(/\s+$/, "")
      #if te
      m = /^\/\/\/(.*)\/\/\/\w*$/.exec(text)
      if m?
        text = m[1].replace(/\s+/, "")
      else
        m = /^\/(.*)\/\w*$/.exec(text)
        if m?
          text = m[1]

      foo =
        /abc/

      if not @isVisible or @currentRegex != text
        @.find('div.error-message').remove()
        try
          @showRailRoadDiagram(text)
        catch error
          #console.log error
          if not @isVisible
            @showRailRoadDiagram("")

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

  showRailRoadDiagram: (regex) ->
    rr = atom.workspaceView.find '.regex-railroad-diagram'
    if not rr.length
      # create current diff
      @hide()

      # append to "panes"
      atom.workspaceView.getActivePaneView().parents('.panes').eq(0).after(@)

    @children().remove()
    Regex2RailRoadDiagram(regex, @.get(0))

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

    statusBar = atom.workspaceView.find('.status-bar')

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
