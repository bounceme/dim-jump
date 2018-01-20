/^\s*['(]*(:type /,+1 {
	s/^\s*[(']*:type\s\s*\("[^"]*"\)\s\s*:supports\s\s*(\([^)]*\))\s\s*:language\s\s*\("[^"]*"\).*/{"type": \1,"supports": split('\2','[ "]\\+'),"language": \3,/;
	s/^\s*:regex\s\s*\("\(\\.\|[^"]\)*"\).*/"regex": \1},/;
	t prin;
	b;
	: prin { 
		s/\([^\\]\(\\\\\)\(\\\\\)*\)\\\([^"\\]\)/\1\4/g;
		p;
	}
}
