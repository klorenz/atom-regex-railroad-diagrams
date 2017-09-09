{$} = require 'atom-space-pen-views'
{Regex2RailRoadDiagram} = require './regex-to-railroad.coffee'
{CompositeDisposable, TextEditor} = require 'atom'


class RailroadDiagramElement extends HTMLElement
  createdCallback: ->

  initialize: (@model) ->
    @panel = atom.workspace.addBottomPanel item: this, visible: false
    @classList.add "regex-railroad-diagram"
    @currentRegex = null
    @subscriptions = null
    @createView()
    this

  createView: ->
    @textEditor = new TextEditor
      mini: true
      tabLength: 2
      softTabs: true
      softWrapped: false
      placeholderText: 'Type in your regex'

    @textEditorSubscriptions = new CompositeDisposable

    @is_visible = false

    changeDelay = null
    @textEditorSubscriptions.add @textEditor.onDidChange =>
      # TODO: if inserted a (, add the ) (and so on.)

      @showRailRoadDiagram @textEditor.getText(), @options


      # # with a little delay, we do not get flickering if person types fast
      # if changeDelay
      #   clearTimeout(changeDelay)
      #   changeDelay = null
      #
      # changeDelay = setTimeout(
      #   (=> @showRailRoadDiagram @textEditor.getText(), @options),
      #   300)

    @regexGrammars = {}
    for grammar in atom.grammars.getGrammars()
      console.log "grammar", grammar.name
      if grammar.name?.match /.*reg.*ex/i
        displayName = grammar.name
        @textEditor.setGrammar(grammar)
        #if m = grammar.name.match /\((.*)\)/
        #  displayName = m[1]
        @regexGrammars[grammar.name] = grammar

    possibleGrammars = [
      'Regular Expression Replacement (Javascript)'
      'Regular Expressions (Javascript)'
      'Regular Expressions (Python)'
    ]

    for name in possibleGrammars
      if name in @regexGrammars
        @textEditor.setGrammar(@regexGrammars[name])
        break

    @innerHTML = """
      <section class="section settings-view">
        <div class="texteditor-container">
        </div>
        <div class="btn-group option-buttons">
          <button class="btn btn-multiline">m</button>
          <button class="btn btn-dotall">s</button>
        </div>
      </section>
      <div class="regex-railroad-view-container">
      </div>
    """

    @viewContainer = @querySelector('.regex-railroad-view-container')
    @options = null

    @multilineButton = @querySelector('.btn-multiline')
    @dotallButton = @querySelector('.btn-dotall')

    btnClick = (btnSelector, opt) =>
      btn = @querySelector(btnSelector)
      if 'selected' in btn.classList
        btn.classList.remove 'selected'
        @options.options = @options.options.replace opt, ''
      else
        btn.classList.add 'selected'
        @options.options = @options.options + opt

      @showRailRoadDiagram @textEditor.getText(), @options

    @multilineButton.onclick = =>
      btnClick '.btn-multiline','m'

    @dotallButton.onclick = =>
      btnClick '.btn-dotall','s'

    @textEditorView = atom.views.getView(@textEditor)

    @querySelector('.texteditor-container').appendChild @textEditorView

    @textEditorSubscriptions.add atom.commands.add @textEditor.element,
      'core:confirm': => @confirm()
      'core:cancel':  => @cancel()

  focusTextEditor: ->
    @textEditorView.focus()

  confirm: ->
    editor = atom.workspace.getActiveTextEditor()
    selections = editor.getSelections()
    for selection in selections
      editor.setTextInBufferRange selection.getBufferRange(), @textEditor.getText()
    atom.views.getView(atom.workspace).focus()

  cancel: ->
    @assertHidden()
    atom.views.getView(atom.workspace).focus()

  isVisible: ->
    @is_visible

  setModel: (@model) ->

  removeDiagram: ->
    for child in @viewContainer.childNodes
      child.remove()
    @subscriptions?.dispose()

  destroy: ->
    @is_visible = false
    @removeDiagram()
    @panel.remove()
    @remove()
    @textEditorSubscriptions?.dispose()

  showDiagram: (regex, options) ->
    return if @currentRegex is regex and not @hidden and options.options is @options?.options
    @is_visible = true
    @activeEditor = atom.workspace.getActiveTextEditor()
    @options = options
    @textEditor.setText(regex)
    @panel.show()

  showRailRoadDiagram: (regex, options) ->
    @removeDiagram()

    @subscriptions = new CompositeDisposable
    try
      Regex2RailRoadDiagram regex, @viewContainer, options

      for e in $(@viewContainer).find('g[title]')
        @subscriptions.add atom.tooltips.add e, title: $(e).attr('title')

      @currentRegex = regex
    catch e
      @showError regex, e

    setTimeout (=> @activeEditor.scrollToCursorPosition()), 200

  showError: (regex, e) ->
    #console.log "caught error when trying to display regex #{regex}", e.stack
    if e.offset
      sp = " ".repeat e.offset
      @viewContainer.innerHTML = """<div class="error-message"><pre class="text-error">#{regex}\n#{sp}^ #{e.message}</pre></div>"""
    else
      @viewContainer.innerHTML = """<div class="error-message"><pre>#{regex}</pre><p class="text-error">#{e.message}</p></div>"""

  assertHidden: ->
    @panel.hide() unless @hidden
    @currentRegex = null
    @subscriptions?.dispose()
    @is_visible = false

module.exports = RailroadDiagramElement = document.registerElement 'regex-railroad-diagram', prototype: RailroadDiagramElement.prototype
