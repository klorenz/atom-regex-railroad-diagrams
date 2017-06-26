# regex-railroad-diagram package

A regular expression railroad diagram view for regular expression
under cursor.

An (old) Screenshot:

![regex-railraod-diagram in action](https://raw.githubusercontent.com/klorenz/atom-regex-railroad-diagrams/master/regex-railroad-diagrams.png)

It also shows you a parsing error message, if your regex is not syntactically
correct.

Regexes parsed are not language specific, so some language specific features may
not parsed or displayed correctly.

## Usage

- if the cursor is on some text, which is marked by language as a regex, the
  railroad diagram automatically opens.  It changes, while you change the text.

- if you have some text selected or your cursor is somewhere else (where no
  regex is recognized), you can hit **ctrl-r ctrl-r** to open the railroad
  diagram view.  You then can edit the regex and hit **enter** to insert it at your cursor position or replace current selection.  Hit **esc** to cancel the view

## Contributors

Many thanks to @mikesprague, who maintains this package, and to other contributers:

- @hayes
- @imperez
- @ypresto
- @goddamnhippie
- @jkroso
- @lucas-clemente
