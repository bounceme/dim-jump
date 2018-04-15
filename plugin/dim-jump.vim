if exists('g:loaded_dimjump')
  finish
endif
let g:loaded_dimjump = 1

let s:langmap = [
      \ ['dsp', 'lib'],
      \ ['lisp', 'lsp'],
      \ ['c', 'h'],
      \ ['c', 'h', 'tpp', 'cpp', 'hpp', 'cxx', 'hxx', 'cc', 'hh', 'c++', 'h++'],
      \ ['ex', 'exs', 'eex'],
      \ ['clj', 'cljc', 'cljs', 'cljx'],
      \ ['sh', 'bash', 'csh', 'ksh', 'tcsh'],
      \ ['ml', 'mli', 'mll', 'mly'],
      \ ['hs', 'lhs'],
      \ ['php', 'php3', 'php4', 'php5', 'phtml', 'inc'],
      \ ['js', 'jsx', 'vue'],
      \ ['r', 'rmd', 'rnw', 'rtex', 'rrst'],
      \ ['pl', 'pm', 'pm6', 'perl', 'plh', 'plx', 'pod', 't'],
      \ ['rb', 'erb', 'haml', 'slim'],
      \ ['f', 'f77', 'f90', 'f95', 'f03', 'for', 'ftn', 'fpp'],
      \ ]

function s:jn(...) abort
  return join(a:000)
endfunction

function s:Fileext(f) abort
  let fe = matchstr(s:langmap, string(fnamemodify(a:f,':e')))
  if len(fe) > 1
    return s:jn('find', getcwd(), escape(s:jn(
          \ '( -iname', join(map(copy(fe), 'string("*.".v:val)'), ' -or -iname '),
          \ ')'), '()'), '-print0 | xargs -0')
  endif
  return s:jn('find', getcwd(), '-iname', string('*.'.fnamemodify(a:f,':e')),
        \ '-print0 | xargs -0')
endfunction

let [s:ag, s:rg, s:grep] = ['', '', '']
function s:prog() abort
  if get(b:,'preferred_searcher') !~# '^\%([ar]g\|\%(git-\)\=grep\)$'
    if system('git rev-parse --is-inside-work-tree')[:-2] is# 'true'
      let b:preferred_searcher = 'git-grep'
      return
    elseif empty(s:ag.s:rg.s:grep)
      for p in ['ag', 'rg', 'grep']
        if executable(p)
          let s:{p} = p
          let s:gnu = p ==# 'grep' && systemlist('grep --version')[0] =~# 'GNU'
          break
        endif
      endfor
    endif
    let b:preferred_searcher = matchstr([s:ag, s:rg, s:grep],'.')
  endif
endfunction

let s:timeout = executable('timeout') ? 'timeout 5' : executable('gtimeout') ? 'gtimeout 5' : ''
let s:f = fnamemodify(expand('<sfile>:p:h:h'),':p').'jump-extern-defs.json'

function s:wordpat(token,cmd) abort
  let ft = escape(substitute('''"!:~`@#$%^-\[]&*()+=;<>,./?|{}','\(\k\)\|.','\1','g'),'^-\[]')
  return ft is '' ? substitute(substitute(a:cmd,'\C\\j','\\b','g'), "JJJ",a:token,"g") :
        \ substitute(substitute(a:cmd,'\C\\[jb]','($|^|[^\\w'.ft.'])','g'), "JJJ",
        \ escape(substitute(a:token,'[^[:alnum:]_]','[&]','g'), '^\'), "g")
endfunction

let s:sed = fnamemodify(expand('<sfile>:p:h:h'),':p').'parse.sed'
function s:loaddefs() abort
  if !exists('s:defs')
    if !filereadable(s:f)
      call writefile(systemlist(s:jn('curl -s',
            \ 'https://raw.githubusercontent.com/jacktasia/dumb-jump/master/dumb-jump.el',
            \ '|','sed -n -f',s:sed)), s:f)
    endif
    let raw = join(readfile(s:f))
    sandbox let s:defs = eval('['.raw.']')
  endif
  return s:defs
endfunction

function s:Refine() abort
  let type = []
  let con = filter(deepcopy(s:contexts), 'v:val.language ==? &ft')
  if !len(con)
    return copy(b:dim_jump_lang)
  endif
  let bef = searchpos('\m\S\_s*\<','cnbW')
  let end = searchpos('\m\>\_s*\zs\S','nW')
  for c in con
    let whole = getline(end[0])[end[1]-1] . getline(bef[0])[bef[1]-1]
    if whole =~# join(filter([get(c,'left',''),get(c,'right','')],'len(v:val)'),'\|')
      call add(type,c.type)
    endif
  endfor
  return filter(copy(b:dim_jump_lang),'count(type,v:val.type)')
endfunction

let s:contexts = [
      \ {"language": "javascript","type": "function","right": "^("},
      \ {"language": "javascript","type": "variable","right": "^)","left": "($"},
      \ {"language": "javascript","type": "variable","right": "^\\."},
      \ {"language": "javascript","type": "variable","right": "^;"},
      \ {"language": "perl","type": "function","right": "^("},
      \ {"language": "elisp","type": "function","left": "($"},
      \ {"language": "elisp","type": "variable","right": "^)"}
      \ ]

let s:transforms = {
      \ 'clojure': 'substitute(JJJ,".*/","","")',
      \ 'ruby': 'substitute(JJJ,"^:","","")'
      \ }
function s:prune(kw) abort
  if has_key(s:transforms,&ft)
    return eval(substitute(s:transforms[&ft],'\CJJJ',string(a:kw),'g'))
  endif
  return a:kw
endfunction

let s:searchprg  = {
      \ 'rg': {'opts': '--no-messages --color never --vimgrep -e'},
      \ 'grep': {'opts': '--no-messages -rnH --color=never -E -e'},
      \ 'git-grep': {'opts': '--untracked --line-number --no-color -E -e'},
      \ 'ag': {'opts': '--silent --nocolor --vimgrep'}
      \ }

function s:Grep(token) abort
  let args = map(s:Refine(),'v:val.regex')
  if args == []
    silent! exe "norm! [\<Tab>"
    return
  endif
  let grepf = &errorformat
  set errorformat&vim
  if b:preferred_searcher ==# 'grep'
    let args = join(map(args,'shellescape(v:val)'),' -e ')
    if s:gnu
      let args = substitute(args,'\C\\s','[[:space:]]','g')
    endif
  else
    let args = shellescape(join(args,'|'))
  endif
  let args = s:wordpat(a:token,args)
  let grepcmd = s:jn(s:timeout,s:Fileext(expand('%')),tr(b:preferred_searcher,'-',' ')
        \ ,s:searchprg[b:preferred_searcher]['opts'],args,'--')
  let prev = getqflist()
  let res = systemlist(grepcmd)
  if len(res)
    silent cexpr sort(res,function('s:funcsort'))[0]."\n"
    if getline('.')[col('.')-1] !~ '\k'
      call search('\V\<'.escape(a:token,'\').'\>','W')
    endif
    call setqflist(prev,'r')
  endif
  let &errorformat = grepf
endfunction

function s:funcsort(a,b) abort
  let [a,b] = map([a:a,a:b],'matchstr(v:val,"^\\f\\+")')
  let c = (index([a,0,b],expand('%')) - 1) % 2
  if c
    return c
  endif
  return len(split(fnamemodify(b,':.'),'/')) -
        \ len(split(fnamemodify(a,':.'),'/'))
endfunction

function s:GotoDefCword() abort
  call s:prog()
  let kw = s:prune(expand('<cword>'))
  if kw isnot ''
    if !exists('b:dim_jump_lang')
      let b:dim_jump_lang = filter(deepcopy(s:loaddefs(),1),
            \ 'v:val.language ==? &ft && count(v:val.supports, b:preferred_searcher)')
    endif
    call s:Grep(kw)
  endif
endfunction

command DimJumpPos call <SID>GotoDefCword()
