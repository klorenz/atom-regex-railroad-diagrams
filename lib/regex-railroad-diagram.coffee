RegexRailroadDiagramView = require './regex-railroad-diagram-view'

module.exports =
  regexRailroadDiagramView: null

  activate: (state) ->
    @regexRailroadDiagramView = new RegexRailroadDiagramView(state.regexRailroadDiagramViewState)

  deactivate: ->
    @regexRailroadDiagramView.destroy()

  serialize: ->
    regexRailroadDiagramViewState: @regexRailroadDiagramView.serialize()
