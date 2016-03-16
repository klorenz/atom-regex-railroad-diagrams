{$} = require 'atom-space-pen-views'
{Regex2RailRoadDiagram} = require './regex-to-railroad.coffee'
{CompositeDisposable} = require 'atom'


class RailroadDiagramElement extends HTMLElement
  createdCallback: ->

  initialize: (@model) ->
    @panel = atom.workspace.addBottomPanel item: this, visible: false
    @currentRegex = null
    @subscriptions = null
    this

  setModel: (@model) ->

  removeChildren: ->
    for child in @childNodes
      child.remove()

  destroy: ->
    @removeChildren()
    @panel.remove()
    @remove()
    @subscriptions?.dispose()

  showDiagram: (regex, options) ->
    return if @currentRegex is regex and not @hidden

    @subscriptions?.dispose()
    @subscriptions = new CompositeDisposable

    @removeChildren()
    try
      Regex2RailRoadDiagram regex, this, options

      for e in $(this).find('g[title]')
        @subscriptions.add atom.tooltips.add e, title: $(e).attr('title')

      @currentRegex = regex
    catch e
      @showError regex, e

    @panel.show()

  showError: (regex, e) ->
    #console.log "caught error when trying to display regex #{regex}", e.stack
    if e.offset
      sp = " ".repeat e.offset
      @innerHTML = """<div class="error-message"><pre class="text-error">#{regex}\n#{sp}^ #{e.message}</pre></div>"""
    else
      @innerHTML = """<div class="error-message"><pre>#{regex}</pre><p class="text-error">#{e.message}</p></div>"""

  assertHidden: ->
    @panel.hide() unless @hidden
    @currentRegex = null
    @subscriptions?.dispose()


module.exports = RailroadDiagramElement = document.registerElement 'regex-railroad-diagram', prototype: RailroadDiagramElement.prototype
