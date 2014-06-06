RegexRailroadDiagramView = require './regex-railroad-diagram-view'

module.exports =
  regexRailroadDiagramView: null

  activate: (state) ->
    console.log "railroad diagram activated"
    @regexRailroadDiagramView = new RegexRailroadDiagramView(state.regexRailroadDiagramViewState)
    #@regexRailroadDiagramView = new RegexRailroadDiagramView()

  deactivate: ->
    @regexRailroadDiagramView.destroy()

  serialize: ->
    regexRailroadDiagramViewState: @regexRailroadDiagramView.serialize()
