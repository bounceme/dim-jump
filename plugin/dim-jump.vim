if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1

if get(g:,'preferred_searcher') is 0 || g:preferred_searcher !~# '^\%([ar]g\|\%(git-\)\=grep\)$'
  if executable('git') && system('git rev-parse --is-inside-work-tree')[:-2] ==# 'true'
    let g:preferred_searcher = 'git-grep'
  elseif executable('ag')
    let g:preferred_searcher = 'ag'
  elseif executable('rg')
    let g:preferred_searcher = 'rg'
  elseif executable('grep')
    let g:preferred_searcher = 'grep'
    if systemlist('grep --version')[0] =~# 'GNU'
      let s:gnu = 1
    endif
  else
    finish
  endif
endif

let s:timeout = executable('timeout') ? 'timeout 5 ' : executable('gtimeout') ? 'gtimeout 5 ' : ''

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
    return eval(substitute(s:transforms[&ft],'\CJJJ',string(a:kw),'g'))
  endif
  return a:kw
endfunction

let s:searchprg  = {
      \ 'rg': {'opts': ' --no-messages --color never --vimgrep -g ''*.%:e'' '},
      \ 'grep': {'opts': ' --no-messages -rnH --color=never --include=''*.%:e'' -E -e '},
      \ 'git-grep': {'opts': ' --untracked --line-number --no-color -E -e '},
      \ 'ag': {'opts': ' --silent --nocolor --vimgrep -G ''.*\.%:e$'' '}
      \ }

function s:Grep(searcher,regparts,token)
  let grepf = &errorformat
  set errorformat&vim
  let args = "'\\bJJJ\\b'"
  if !empty(a:regparts)
    if a:searcher =~# 'grep'
      if a:searcher =~# 'git'
        let args = shellescape(join(a:regparts,'|'))
      else
        let args = join(map(a:regparts,'shellescape(v:val)'),' -e ')
        if exists('s:gnu')
          let args = substitute(args,'\C\\s','[[:space:]]','g')
        endif
      endif
    else
      let args = shellescape(join(a:regparts,'|'))
    endif
    if &isk =~ '\%(^\|,\)-'
      if a:searcher ==# 'ag'
        let args = substitute(args,'\C\\j','(?!|[^\\w-])','g')
      else
        let args = substitute(args,'\C\\j','($|[^\\w-])','g')
      endif
    else
      let args = substitute(args,'\C\\j','\\b','g')
    endif
  endif
  if a:searcher ==# 'git-grep'
    let args .= " -- '*.".expand('%:e')."'"
  endif
  let grepcmd = s:timeout . tr(a:searcher,'-',' ')
        \ . substitute(substitute(s:searchprg[a:searcher]['opts']
        \ , '\C%:e', '\=expand(submatch(0))', 'g')
        \ . args
        \ , '\CJJJ', a:token, 'g')
  silent! cexpr system(grepcmd)
  let &errorformat = grepf
endfunction

function s:GotoDefCword()
  if !exists('b:dim_jump_lang')
    let b:dim_jump_lang = filter(deepcopy(s:defs),'v:val.language ==? &ft')
  endif
  let patterns = []
  for d in b:dim_jump_lang
    if index(d.supports,g:preferred_searcher) != -1
      call add(patterns,d.regex)
    endif
  endfor
  call s:Grep(g:preferred_searcher, patterns, s:prune(expand('<cword>')))
endfunction

command DimJumpPos call <SID>GotoDefCword()
