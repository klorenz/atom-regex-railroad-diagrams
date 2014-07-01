grammar =
    macros:
      {}

    init: (s) ->
      class Parsing
        constructur: (@string) ->
          @capture = 0

    rules:
      RegEx:
        o "RegEx *",  (regex) -> OneOrMore(0, regex)
        o "RegEx ?",  (regex) -> OneOrMore(0, regex, Comment("0 or 1 time"))
        o "RegEx +", (regex) -> ZeroOrMore()
        o "RegEx Quantifier",   (regex, quantifier) ->
          {min, max} = quantifier
          if min == 0
            ZeroOrMore(0, regex, Comment("#{max} times"))
          else if min == max
            if min == 1
              OneOrMore(0, regex, Comment("once"))
            else
              OneOrMore(0, regex, Comment("#{max} times"))
          else
            OneOrMore(0, regex, Comment("#{min} to #{max} times"))
        o "(?= Regex )", (regex) -> Sequence(0, regex, Comment("Lookahead")) # maybe we pass some extra classed for getting this boxed
        o "(?! Regex )", (regex) -> Sequence(0, regex, Comment("Negative Lookahead")) # maybe we pass some extra classed for getting this boxed
        o "(?<= Regex )", (regex) -> Sequence(0, regex, Comment("Lookbehind")) # maybe we pass some extra classed for getting this boxed
        o "(?<! Regex )", (regex) -> Sequence(0, regex, Comment("Negative Lookbehind")) # maybe we pass some extra classed for getting this boxed
        o "(?P< IDENT > Regex )", (name, regex) ->
          Sequence(0, regex, Comment("Capture #{capture} (#{name})")) # maybe we pass some extra classed for getting this boxed
          @capture += 1
        o "( RegEx )", (regex) ->
          Sequence(0, "capture #{capture}")
          @capture += 1

        o "Regex Regex"

      Quantifier:
        -> "{ , }",         () -> min: 0, max: Infinity
        -> "{ INT , }",     (start) -> min: start, max: Infinity
        -> "{ INT , INT }", (start, end) -> min: start, max: max
        -> "{ , INT }",     (end) -> min: 0, max: max
