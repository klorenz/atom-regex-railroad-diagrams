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
          sequence.push NonTerminal("SP", "Space character")
        else
          sequence.push OneOrMore(NonTerminal("SP", "Space character"), Comment("#{part.length} times"))
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
      literal = null
      sequence = []

      for n in node.body
        if n.type is "literal"  # and not n.escaped
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

      plural = (x) -> if x != 1 then "s" else ""

      switch min
        when 0
          if max is 1
            Optional(body)
          else
            if max == 0
              ZeroOrMore(body, quantifiedComment("0x", greedy, title: "exact 0 times repitition does not make sense"))
            else if max != Infinity
              ZeroOrMore(body, quantifiedComment("0-#{max}x", greedy, title: "repeat 0 to #{max} time" + plural(max)))
            else
              ZeroOrMore(body, quantifiedComment("*", greedy, title: "repeat zero or more times"))
        when 1
          if max == 1
            OneOrMore(body, Comment("1", title: "once"))
          else if max != Infinity
            OneOrMore(body, quantifiedComment("1-#{max}x", greedy, title: "repeat 1 to #{max} times"))
          else
            OneOrMore(body, quantifiedComment("+", greedy, title: "repeat at least one time"))
        else
          if max == min
            OneOrMore(body, Comment("#{max}x", title: "repeat #{max} times"))
          else if max != Infinity
            OneOrMore(body, quantifiedComment("#{min}-#{max}x", greedy, title: "repeat #{min} to #{max} times"))
          else
            OneOrMore(body, quantifiedComment(">= #{min}x", greedy, title: "repeat at least #{min} time" + plural(min)))

    when "capture-group"
      Group rx2rr(node.body, options), Comment("capture #{node.index}"), minWidth: 55

    when "non-capture-group"
      Group rx2rr(node.body, options)

    when "positive-lookahead", "negative-lookahead", \
         "positive-lookbehind", "negative-lookbehind"
      Group rx2rr(node.body, options), Comment(node.type)

    when "back-reference"
      NonTerminal("#{node.code}", "Match capture #{node.code} (Back Reference)")

    when "literal"
      if node.escaped
        #Terminal("\\"+node.body)
        Terminal(node.body)
      else
        makeLiteral(node.body)

    when "start"
      NonTerminal("START", "Beginning of string")

    when "end"
      NonTerminal("END", "End of string")

    when "word"
      NonTerminal("WORD", "Word character A-Z, 0-9, _")

    when "non-word"
      NonTerminal("NON-WORD", "Non-word character, all except A-Z, 0-9, _")

    when "line-feed"
      NonTerminal("LF", "Line feed '\\n'")

    when "carriage-return"
      NonTerminal("CR", "Carriage Return '\\r'")

    when "vertical-tab"
      NonTerminal("VTAB", "Vertical tab '\\v'")

    when "tab"
      NonTerminal("TAB", "Tab stop '\\t'")

    when "form-feed"
      NonTerminal("FF", "Form feed")

    when "back-space"
      NonTerminal("BS", "Backspace")

    when "digit"
      Terminal("0-9")

    when "null-character"
      Terminal("NULL", "Null character '\\0'")

    when "non-digit"
      NonTerminal("not 0-9", "All except digits")

    when "white-space"
      NonTerminal("WS", "Whitespace: space, tabstop, linefeed, carriage-return, etc.")

    when "non-white-space"
      NonTerminal("NON-WS", "Not whitespace: all except space, tabstop, line-feed, carriage-return, etc.")

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

    when "any-character"
      NonTerminal("ANY", "Any character except Newline")

    else
      NonTerminal(node.type)

      # word-boundary
      # non-word-boundary
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

quantifiedComment = (comment, greedy, attrs) ->
  if comment and greedy
    attrs.title += ', longest possible match'
    Comment(comment + ' (greedy)', attrs)
  else if greedy
    attrs.title = 'longest possible match'
    Comment('greedy', attrs)
  else if comment
    attrs.title += ', shortest possible match'
    Comment(comment + ' (lazy)', attrs)
  else
    attrs.title = 'shortest possible match'
    Comment('lazy', attrs)

parseRegex = (regex) ->
  if regex instanceof RegExp
    regex = regex.source

  parse regex

module.exports =
  Regex2RailRoadDiagram: (regex, parent, opts) ->
    Diagram(rx2rr(parseRegex(regex), opts)).addTo(parent)

  ParseRegex: parseRegex
