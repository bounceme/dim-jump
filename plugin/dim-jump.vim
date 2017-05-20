if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1
let defs = json_decode(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json'))
