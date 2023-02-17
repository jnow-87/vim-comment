if exists("g:loaded_comment") || &compatible
	finish
endif

let g:loaded_comment = 1

" get own script ID
nmap <c-f11><c-f12><c-f13> <sid>
let s:sid = "<SNR>" . maparg("<c-f11><c-f12><c-f13>", "n", 0, 1).sid . "_"
nunmap <c-f11><c-f12><c-f13>


""""
"" global variables
""""

"{{{
let g:comment_map = get(g:, "comment_map", "cl")
let g:comment_strings = get(g:, "comment_strings", {}) 
"}}}


""""
"" local variables
""""

"{{{
let s:comment_strings = {}
let s:comment_patterns = {}
"}}}


""""
"" local functions
""""

"{{{
" \brief	update the patterns for (un)commenting for the current filetype
" 			based on &commentstring and the user setting in g:comment_strings
function s:update_patterns()
	if !has_key(s:comment_strings, &filetype)
		let l:s = get(g:comment_strings, &filetype, &commentstring)

		let s:comment_strings[&filetype] = l:s
		let s:comment_patterns[&filetype] = substitute(escape(l:s, "*+.\\"), "%s", '\\(.*\\)', "")
	endif
endfunction
"}}}

"{{{
" \brief	check if the <line> is commented or not
"
" \param	line	line to check
"
" \return	0 line is not commented
" 			1 line is commented
function s:commented(line)
	return (match(a:line, s:comment_patterns[&filetype]) == 0)
endfunction
"}}}

"{{{
" \brief	(un)comment line under cursor
function s:comment()
	if !has_key(s:comment_strings, &filetype)
		return
	endif

	let l:line = getline(".")
	let l:line = s:commented(l:line)
		\ ? substitute(l:line, s:comment_patterns[&filetype], '\1', "")
		\ : printf(s:comment_strings[&filetype], l:line)

	call setline(line("."), l:line)
endfunction
"}}}


""""
"" autocommands
""""

autocmd FileType * call s:update_patterns()


""""
"" mappings
""""

call util#map#n(g:comment_map, ":call " . s:sid . "comment()<cr>", "")
call util#map#v(g:comment_map, ":call " . s:sid . "comment()<cr>", "")
