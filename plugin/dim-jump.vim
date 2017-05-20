if exists('g:loaded_dimjump') || !exists('*json_decode')
  finish
endif
let g:loaded_dimjump = 1

let s:transforms = {}
function s:prune(kw)
  if has_key(s:transforms,&ft)
    return eval(substitute(s:transforms[&ft],'JJJ',string(a:kw),'g'))
  endif
  return a:kw
endfunction

let s:defs = json_decode(join(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json')))
function! s:GotoDefCword()
  if !exists('b:dim_jump_lang')
    let b:dim_jump_lang = filter(s:defs,'v:val.language ==? &ft')
  endif
  let token = s:prune(expand('<cword>'))
  echom string(b:dim_jump_lang)
  echom token
endfunction

command! DimJumpPos call <SID>GotoDefCword()
