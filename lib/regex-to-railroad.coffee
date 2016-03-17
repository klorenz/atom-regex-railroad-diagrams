parse = require "regexp"

{Diagram, Sequence, Choice, Optional, OneOrMore, ZeroOrMore, Terminal,
 NonTerminal, Comment, Skip, Group } = require './railroad-diagrams'

doSpace = -> NonTerminal("SP", title: "Space character", class: "literal whitespace")


makeLiteral = (text) ->
  #debugger
  if text == " "
    doSpace()
  else
    parts = text.split /(^ +| {2,}| +$)/
    sequence = []
    for part in parts
      continue unless part.length
      if /^ +$/.test(part)
        if part.length == 1
          sequence.push doSpace()
        else
          sequence.push OneOrMore(doSpace(), Comment("#{part.length}x", title: "repeat #{part.length} times"))
      else
        sequence.push Terminal(part, class: "literal")

    if sequence.length == 1
      sequence[0]
    else
      new Sequence sequence

get_flag_name = (flag) ->
  flag_names = {
    A: 'pcre:anchored'
    D: 'pcre:dollar-endonly'
    S: 'pcre:study'
    U: 'pcre:ungreedy'
    X: 'pcre:extra'
    J: 'pcre:extra'
    i: 'case-insensitive'
    m: 'multi-line'
    s: 'dotall'
    e: 'evaluate'
    o: 'compile-once'
    x: 'extended-legilibility'
    g: 'global'
    c: 'current-position'
    p: 'preserve'
    d: 'no-unicode-rules'
    u: 'unicode-rules'
    a: 'ascii-rules'
    l: 'current-locale'
  }

  if flag of flag_names
    flag_names[flag]
  else
    "unknown:#{flag}"

rx2rr = (node, options) ->
  opts = options.options

  isSingleString = -> opts.match /s/

  doStartOfString = ->
    if opts.match /m/
      title = "Beginning of line"
    else
      title = "Beginning of string"
    NonTerminal("START", title: title, class: 'zero-width-assertion')

  doEndOfString   = ->
    if opts.match /m/
      title = "End of line"
    else
      title = "End of string"

    NonTerminal("END", title: title, class: 'zero-width-assertion')

#  debugger
  switch node.type
    when "match"
      literal = ''
      sequence = []

      for n in node.body
        if n.type is "literal" and n.escaped
          if n.body is "A"
            sequence.push doStartOfString()
          else if n.body is "Z"
            sequence.push doEndOfString()
          else
            literal += n.body

        else if n.type is "literal"  # and not n.escaped
          literal += n.body
        else
          if literal
            sequence.push makeLiteral(literal)
            literal = ''

          sequence.push rx2rr n, options

      if literal
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
      text = "capture #{node.index}"
      min_width = 55
      if node.name
        text += " (#{node.name})"
        min_width = 55 + (node.name.split('').length+3)*7
      Group rx2rr(node.body, options), Comment(text, class: "caption"), minWidth: min_width, attrs: {class: 'capture-group group'}

    when "flags"
      turn_on_long = []
      turn_off_long = []
      console.log node
      flags = node.body.join('')
      [turn_on, turn_off] = flags.split('-')
      turn_on ?= ''
      turn_off ?= ''
      for f in turn_on.split('')
        turn_on_long.push get_flag_name(f)

      for f in turn_off.split('')
        if f == 'i'
          turn_on_long.push('case-sensitive')
        else
          turn_off_long.push get_flag_name(f)

      _title = []
      if turn_on
        _title.push "Turn on: "+turn_on_long.join(', ')
      if turn_off
        _title.push "Turn off: "+turn_off_long.join(', ')

      NonTerminal("SET: "+node.body.join(''), title: _title.join("\n"), class: 'zero-width-assertion')
      #NonTerminal("WORD", title: "Word character A-Z, 0-9, _", class: 'character-class')

    when "non-capture-group"
      # Group rx2rr(node.body, options), null, attrs: {class: 'group'}
      rx2rr(node.body, options)

    when "positive-lookahead"
      Group rx2rr(node.body, options), Comment("=> ?", title: "Positive lookahead", class: "caption"), attrs: {class: "lookahead positive zero-width-assertion group"}

    when "negative-lookahead"
      Group rx2rr(node.body, options), Comment("!> ?", title: "Negative lookahead", class: "caption"), attrs: {class: "lookahead negative zero-width-assertion group"}

    when "positive-lookbehind"
      Group rx2rr(node.body, options), Comment("<= ?", title: "Positive lookbehind", class: "caption"), attrs: {class: "lookbehind positive zero-width-assertion group"}

    when "negative-lookbehind"
      Group rx2rr(node.body, options), Comment("<! ?", title: "Negative lookbehind", class: "caption"), attrs: {class: "lookbehind negative zero-width-assertion group"}

    when "back-reference"
      NonTerminal("#{node.code}", title: "Match capture #{node.code} (Back Reference)", class: 'back-reference')

    when "literal"
      if node.escaped
        if node.body is "A"
          doStartOfString()
        else if node.body is "Z"
          doEndOfString()
        else
          #Terminal("\\"+node.body)
          Terminal(node.body, class: "literal")
      else
        makeLiteral(node.body)

    when "start"
      doStartOfString()

    when "end"
      doEndOfString()

    when "word"
      NonTerminal("WORD", title: "Word character A-Z, 0-9, _", class: 'character-class')

    when "non-word"
      NonTerminal("NON-WORD", title: "Non-word character, all except A-Z, 0-9, _", class: 'character-class invert')

    when "line-feed"
      NonTerminal("LF", title: "Line feed '\\n'", class: 'literal whitespace')

    when "carriage-return"
      NonTerminal("CR", title: "Carriage Return '\\r'", class: 'literal whitespace')

    when "vertical-tab"
      NonTerminal("VTAB", title: "Vertical tab '\\v'", class: 'literal whitespace')

    when "tab"
      NonTerminal("TAB", title: "Tab stop '\\t'", class: 'literal whitespace')

    when "form-feed"
      NonTerminal("FF", title: "Form feed", class: 'literal whitespace')

    when "back-space"
      NonTerminal("BS", title: "Backspace", class: 'literal')

    when "digit"
      NonTerminal("0-9", class: 'character-class')

    when "null-character"
      NonTerminal("NULL", title: "Null character '\\0'", class: 'literal')

    when "non-digit"
      NonTerminal("not 0-9", title: "All except digits", class: 'character-class invert')

    when "white-space"
      NonTerminal("WS", title: "Whitespace: space, tabstop, linefeed, carriage-return, etc.", class: 'character-class whitespace')

    when "non-white-space"
      NonTerminal("NON-WS", title: "Not whitespace: all except space, tabstop, line-feed, carriage-return, etc.", class: 'character-class invert')

    when "range"
      NonTerminal(node.text, class: "character-class")

    when "charset"
      charset = (x.text for x in node.body)

      if charset.length == 1
        char = charset[0]

        if char == " "
          if node.invert
            return doSpace()

        if node.invert
          return NonTerminal("not #{char}", title: "Match all except #{char}", class: 'character-class invert')
        else
          if char is "SP"
            return doSpace()
          else
            return Terminal(char, class: "literal")
      else
        list = charset[0...-1].join(", ")

        for x,i in list
          if x == " "
            list[i] = "SP"

        if node.invert
          return NonTerminal("not #{list} and #{charset[-1..]}", class: 'character-class invert')
        else
          return NonTerminal("#{list} or #{charset[-1..]}", class: 'character-class')

    when "hex", "octal", "unicode"
      Terminal(node.text, class: 'literal charachter-code')

    when "unicode-category"
      _text = node.code
      _class = 'unicode-category character-class'
      if node.invert
        _class += ' invert'
        _text = "NON-#{_text}"

      NonTerminal(_text, title: "Unicode Category #{node.code}", class: _class)

    when "any-character"
      extra = unless isSingleString() then " except newline" else ""
      NonTerminal("ANY", title: "Any character#{extra}" , class: 'character-class')

    when "word-boundary"
      NonTerminal("WB", title: "Word-boundary", class: 'zero-width-assertion')

    when "non-word-boundary"
      NonTerminal("NON-WB", title: "Non-word-boundary (match if in a word)", class: 'zero-width-assertion invert')

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
    attrs.class = 'quantified greedy'
    Comment(comment + ' (greedy)', attrs)
  else if greedy
    attrs.title = 'longest possible match'
    attrs.class = 'quantified greedy'
    Comment('greedy', attrs)
  else if comment
    attrs.title += ', shortest possible match'
    attrs.class = 'quantified lazy'
    Comment(comment + ' (lazy)', attrs)
  else
    attrs.title = 'shortest possible match'
    attrs.class = 'quantified lazy'
    Comment('lazy', attrs)

parseRegex = (regex) ->
  if regex instanceof RegExp
    regex = regex.source

  parse regex

module.exports =
  Regex2RailRoadDiagram: (regex, parent, opts) ->
    Diagram(rx2rr(parseRegex(regex), opts)).addTo(parent)

  ParseRegex: parseRegex
