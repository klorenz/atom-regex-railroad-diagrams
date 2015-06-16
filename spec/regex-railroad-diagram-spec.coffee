{WorkspaceView} = require 'atom'
RegexRailroadDiagram = require '../lib/regex-railroad-diagram'

{ParseRegex, Regex2RailRoadDiagram} = require '../lib/regex-to-railroad'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.


describe "RegexRailroadDiagram", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('regex-railroad-diagram')

  describe "regex-to-railroad diagram converter", ->

    it "parses a regex with alternatives", ->
      r = ParseRegex /a|b|c/
      expect(r.toString()).toEqual  {
        type: 'alternate', offset: 0, text : 'a|b|c', left : {
          type : 'match', offset : 0, text : 'a', body : [
            {
              type : 'literal', offset : 0,
              text : 'a', body : 'a', escaped : false
            }
          ]
        }, right : {
          type : 'alternate', offset : 2, text : 'b|c', left : {
            type : 'match', offset : 2, text : 'b', body : [
              {
                type : 'literal', offset : 2,
                text : 'b', body : 'b', escaped : false
              }
            ]
          }, right : {
            type : 'match', offset : 4, text : 'c', body : [
              {
                type : 'literal', offset : 4, text : 'c',
                body : 'c', escaped : false
              }
            ]
          }
        }
      }.toString()

    it "parses a regex", ->
      r = Regex2RailRoadDiagram /foo*/, null
      expect(r).toBe "foo"

  describe "when the regex-railroad-diagram:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.regex-railroad-diagram')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'regex-railroad-diagram:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.regex-railroad-diagram')).toExist()
        atom.workspaceView.trigger 'regex-railroad-diagram:toggle'
        expect(atom.workspaceView.find('.regex-railroad-diagram')).not.toExist()
