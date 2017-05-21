if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1

try
  let s:defs = json_decode(join(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json')))
catch
  try
    let s:strdefs = join(readfile(fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json'))
    sandbox let s:defs = eval(s:strdefs)
  catch
    unlet! s:defs
    finish
  finally
    unlet! s:strdefs
  endtry
endtry

let s:transforms = {
      \ 'clojure': 'substitute(JJJ,".*/","","")',
      \ 'ruby': 'substitute(JJJ,"^:","","")'
      \ }
function s:prune(kw)
  if has_key(s:transforms,&ft)
    return eval(substitute(s:transforms[&ft],'JJJ',string(a:kw),'g'))
  endif
  return a:kw
endfunction

" https://gist.github.com/bounceme/72aa91b4f2a473818d93384b7fff3bd4
function s:FilterQf(ob)
  let [cc,bnr] = [[],bufnr('%')]
  let shm = &shortmess
  set shortmess+=A
  for i in a:ob
    silent! exe 'hide keepalt keepjumps b ' . get(i,'bufnr')
    let [ln,cl] = [get(i,'lnum'),get(i,'col')]
    if synIDattr(synID(ln, cl ? cl : matchend(getline(ln),'^\s*\S'),0),'name')
          \ !~? 'string\|regex\|comment'
      call add(cc,deepcopy(i))
    endif
  endfor
  silent! exe 'keepalt keepjumps b ' . bnr
  let &shm = shm
  return cc
endfunction

let s:preferred = 'rg'
let s:searchprg  = {'rg': {'opts': ' --color never --no-heading '}}

function s:Grep(searcher,regparts,token)
  let grepr = &grepprg
  let &grepprg = escape(a:searcher
        \ . substitute(s:searchprg[a:searcher].opts
        \ . shellescape(join(a:regparts,'|')), 'JJJ','$*','g'), '|')
  exe 'grep ' . a:token
  let &grepprg = grepr
endfunction

function s:GotoDefCword()
  if !exists('b:dim_jump_lang')
    let b:dim_jump_lang = filter(deepcopy(s:defs),'v:val.language ==? &ft')
  endif
  let patterns = []
  for d in b:dim_jump_lang
    if index(d.supports,s:preferred) != -1
      call add(patterns,d.regex)
    endif
  endfor
  call s:Grep(s:preferred,patterns,s:prune(expand('<cword>')))
endfunction

command DimJumpPos call <SID>GotoDefCword()
