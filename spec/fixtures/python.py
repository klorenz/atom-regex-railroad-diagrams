import re



re1 = re.compile(r'foo')
re1 = re.compile(r'(foo|bar)')
re1 = re.compile(r'''foo''')
re1 = re.compile(r'(.*)(?=foo)(?!bar)$')

regexShort = r'^(https|ftp|http)://\S*$'
