# regex-railroad-diagram package

A regular expression railroad diagram view for regular expression
under cursor.  This is still in development and for me it is a test of
graphics capabilities of Atom.

![regex-railraod-diagram in action](https://raw.githubusercontent.com/klorenz/atom-regex-railroad-diagrams/3552667228c192e81a0d2e5843e824c064b8e4b9/regex-railroad-diagrams.png)

It also shows you a parsing error message, if your regex is not syntactically
correct.

For now it only supports most common regex features, but there are more   
to come.

TODO
- langauge-coffe-script has a bug and does not allow more than one regex per line :(
- add flavour selector
- add options selector (g,i, etc)
- set a regex syntax highlighting
- on flavour change change regex syntax highlighting
- on hit ESC hide the editor
- on hit ENTER insert the text into code
