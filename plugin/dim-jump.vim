if exists('g:loaded_dimjump') || !exists('*json_decode')
  finish
endif
let g:loaded_dimjump = 1

let s:defs = json_decode(join(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json')))
function! s:GotoDefCword()
  if !exists('b:dim_jump_lang')
    let b:dim_jump_lang = filter(s:defs,'v:val.language ==? &ft')
  endif
  echom string(b:dim_jump_lang)
endfunction

command! DimJumpPos call <SID>GotoDefCword()
