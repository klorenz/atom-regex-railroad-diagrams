while (<>) {
  /foo/

  m{foobar|x/f}
  m{(foo|bar)}

  m/.*/s


  $variablename =~ /REGEX[:alnum:]/
  $variablename =~ /REGEX[[:alnum:]]/
  $variablename =~ m{\d+|\d+}
  $variablename =~ s/REGEX[[:alnum:]]/foo/g
}
