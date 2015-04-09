parse = require "regexp"

{Diagram, Sequence, Choice, Optional, OneOrMore, ZeroOrMore, Terminal,
 NonTerminal, Comment, Skip, Group } = require './railroad-diagrams'

makeLiteral = (text) ->
  #debugger
  if text == " "
    NonTerminal("SP")
  else
    parts = text.split /(^ +| {2,}| +$)/
    sequence = []
    for part in parts
      continue unless part.length
      if /^ +$/.test(part)
        if part.length == 1
          sequence.push NonTerminal("SP")
        else
          sequence.push OneOrMore(NonTerminal("SP"), Comment("#{part.length} times"))
      else
        sequence.push Terminal(part)

    if sequence.length == 1
      sequence[0]
    else
      new Sequence sequence

rx2rr = (node, options) ->
#  debugger
  switch node.type
    when "match"
      #debugger

      literal = null
      sequence = []

      for n in node.body
        if n.type is "literal" and not n.escaped
          if literal?
            literal += n.body
          else
            literal = n.body
        else
          if literal?
            sequence.push makeLiteral(literal)
            literal = null

          sequence.push rx2rr n, options

      if literal?
        sequence.push makeLiteral(literal)

      if sequence.length == 1
        sequence[0]
      else
        new Sequence sequence

    when "alternate"
      alternatives = []
      while node.type is "alternate"
        alternatives.push rx2rr node.left, options
        node = node.right

      alternatives.push rx2rr node, options

      new Choice Math.floor(alternatives.length/2)-1, alternatives

    when "quantified"
      {min, max, greedy} = node.quantifier

      body = rx2rr node.body, options

      throw new Error("Minimum quantifier (#{min}) must be lower than "
          + "maximum quantifier (#{max})") unless min <= max

      switch min
        when 0
          if max is 1
            Optional(body)
          else
            if max == 0
              ZeroOrMore(body, quantifiedComment("#{max} times", greedy))
            else if max != Infinity
              ZeroOrMore(body, quantifiedComment("0 to #{max} times", greedy))
            else
              ZeroOrMore(body, quantifiedComment("", greedy))
        when 1
          if max == 1
            OneOrMore(body, Comment("once"))
          else if max != Infinity
            OneOrMore(body, quantifiedComment("1 to #{max} times", greedy))
          else
            OneOrMore(body, quantifiedComment("", greedy))
        else
          if max == min
            OneOrMore(body, Comment("#{max} times"))
          else if max != Infinity
            OneOrMore(body, quantifiedComment("#{min} to #{max} times", greedy))
          else
            OneOrMore(body, quantifiedComment("at least #{min} times", greedy))

    when "capture-group"
      Group rx2rr(node.body, options), Comment("capture #{node.index}")

    when "non-capture-group"
      Group rx2rr(node.body, options)

    when "positive-lookahead", "negative-lookahead", \
         "positive-lookbehind", "negative-lookbehind"
      Group rx2rr(node.body, options), Comment(node.type)

    when "back-reference"
      NonTerminal("ref #{node.index}")

    when "literal"
      if node.escaped
        #Terminal("\\"+node.body)
        Terminal(node.body)
      else
        makeLiteral(node.body)

    when "word"
      NonTerminal("word-character")

    when "non-word"
      NonTerminal("non-word-character")

    when "line-feed"
      NonTerminal("LF")

    when "carriage-return"
      NonTerminal("CR")

    when "form-feed"
      NonTerminal("FF")

    when "back-space"
      NonTerminal("BS")

    when "digit"
      Terminal("0-9")

    when "white-space"
      NonTerminal("WS")

    when "range"
      Terminal(node.text)

    when "charset"
      charset = (x.text for x in node.body)

      if charset.length == 1
        char = charset[0]

        if char == " "
          char = "SP"

        if node.invert
          return NonTerminal("not #{charset[0]}")
        else
          return Terminal(charset[0])
      else
        list = charset[0...-1].join(", ")

        for x,i in list
          if x == " "
            list[i] = "SP"

        if node.invert
          return NonTerminal("not #{list} and #{charset[-1..]}")
        else
          return NonTerminal("#{list} or #{charset[-1..]}")

    when "hex", "octal", "unicode"
      Terminal(node.text)

    else
      NonTerminal(node.type)

      # any-character
      # backspace
      # word-boundary
      # non-word-boundary
      # digit
      # non-digit
      # form-feed
      # line-feed
      # carriage-return
      # white-space
      # non-white-space
      # tab
      # vertical-tab
      # word
      # non-word
      # ! control-character (not supported)
      # octal \000
      # hex   \x...
      # unicode \u...
      # null-character

quantifiedComment = (comment, greedy) ->
  if comment and greedy
    Comment(comment + ' (greedy)')
  else if greedy
    Comment('greedy')
  else if comment
    Comment(comment + '(lazy)')
  else
    Comment('lazy')

parseRegex = (regex) ->
  if regex instanceof RegExp
    regex = regex.source

  parse regex

module.exports =
  Regex2RailRoadDiagram: (regex, parent, opts) ->
    Diagram(rx2rr(parseRegex(regex), opts)).addTo(parent)

  ParseRegex: parseRegex
