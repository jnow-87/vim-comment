""""
"" check init state
""""
"{{{
if exists("g:_loaded_comment") || &compatible
	finish
endif

let g:loaded_comment = 1
"}}}

""""
"" init script variables
""""
"{{{
let s:marker = {
	\ "c"	: {
		\ "line" : '// ',
		\ "block_l" : '/* ',
		\ "block_r" : ' */',
		\ "blocks_l" : '/**',
		\ "blocks_m" : ' * ',
		\ "blocks_r" : ' */'
	\ }
\ }

call extend(s:marker, { "cpp" : s:marker.c })
call extend(s:marker, { "asm" : s:marker.c })
"}}}

""""
"" local functions
""""
"{{{
" \brief	set buffer-local markers depending on filetype
function s:update_marker()
	if has_key(s:marker, &filetype)
		let b:marker = s:marker[&filetype]
	else
		let cs = split(&commentstring, "%s")

		let b:marker = {
			\ "line" : (len(cs) > 0 ? cs[0] . " " : ""),
			\ "block_l" : (len(cs) > 0 ? cs[0] . " " : ""),
			\ "block_r" : (len(cs) > 1 ? " " . cs[1] : ""),
			\ "blocks_l" : "",
			\ "blocks_m" : "",
			\ "blocks_r" : ""
		\ }
	endif
endfunction

" \brief	search for left-hand marker within line
"
" \param	line	string to be searched
" \param	marker	string to look for
" \param	start	offset where to start searching
"
" \return	index into line if the marker has been found
" 			-1 if marker has not been found
function s:marker_pos_l(line, marker, start)
	" search back- and forwards
	let p_l = strridx(a:line, a:marker, a:start)
	return (p_l == -1 ? stridx(a:line, a:marker, a:start) : p_l)
endfunction

" \brief	search for right-hand marker within line
"
" \param	line	string to be searched
" \param	marker	string to look for
" \param	start	offset where to start searching
"
" \return	index into line if the marker has been found
" 			-1 if marker has not been found
function s:marker_pos_r(line, marker, start)
	return (a:marker == "" ? -1 : stridx(a:line, a:marker, a:start))
endfunction

" \brief	get commented state and markers to be used for given line
"
" \param	line	text to check
" \param	start	offset where to start
" \param	c_type	comment type to be used
" 					'b' - block type
" 					'l' - line type
"
" \return	list [ state, ml, mr ]
" 				state	commented state of the line (0 = not commented, 1 =	commented)
" 				ml		left marker to used
" 				mr		right marker to be used
function s:get_commented(line, start, c_type)
	if a:c_type == 'b' && b:marker.block_l != "" && b:marker.block_r != ""
		let p_l = <sid>marker_pos_l(a:line, b:marker.block_l, a:start)
		let p_r = <sid>marker_pos_r(a:line, b:marker.block_r, p_l)

		if p_l > a:start || p_r < a:start
			let p_l = -1
			let p_r = -1
		endif

		return [ (p_l == -1 || p_r == -1 ? 0 : 1), b:marker.block_l, b:marker.block_r ]
	else
		return [ (<sid>marker_pos_l(a:line, b:marker.line, a:start) == -1 ? 0 : 1), b:marker.line, "" ]
	endif
endfunction
"}}}

""""
"" global functions
""""
"{{{
" \brief	un/comment a single line
"
" \param	lnum		line number
" \param	start		start index into line
" \param	end			end index into line
" \param	marker_l	left marker to be used
" \param	marker_r	right marker to be used
" \param	comment		what to do with the line (0 = uncomment, 1 = comment)
"
" \return	none
function s:comment_line(lnum, start, end, marker_l, marker_r, comment)
	let line = getline(a:lnum)

	if a:comment
		" compose new line - adding marker
		let line = (a:start == 0 ? "" : line[0:a:start-1])
				   \ . a:marker_l
				   \ . line[a:start+0:a:end]
				   \ . a:marker_r
				   \ . (a:end == -1 ? "" : line[a:end+1:-1])
	else
		let p_l = <sid>marker_pos_l(line, a:marker_l, a:start)

		" left marker not found
		if p_l == -1
			return
		endif

		" search for right marker
		let p_r = <sid>marker_pos_r(line, a:marker_r, p_l)

		if strlen(line) == strlen(a:marker_l) + strlen(a:marker_r)
			let line = ""
		else
			" compose new line - removing marker
			let line = (p_l == 0 ? "" : line[0:p_l-1])
					   \ . line[p_l+strlen(a:marker_l):p_r-1]
					   \ . line[p_r+strlen(a:marker_r):-1]
		endif
	endif

	call setline(a:lnum, line)
endfunction

" \brief	main commenting function
"
" \param	mode	vim mode that the function was called in ('v' = visual, 'n' = normal)
" \param	c_type	comment type to be used
" 					'b' - block type
" 					'l' - line type
"
" \return	none
function g:do_comment(mode, c_type)
	if a:mode == 'v'
		" get selection boundaries
		let p_start = getpos("'<")
		let p_end = getpos("'>")

		" getpos() columns ranges are 1.., map them to 0..
		let p_start[2] -= 1
		let p_end[2] -= 1

		" get markers and commented state
		if p_start[1] == p_end[1]
			" if single line: only check selected range
			let [ commented, marker_l, marker_r ] = <sid>get_commented(getline(p_start[1])[p_start[2]:-1], 0, a:c_type)
		else
			" if multiple are selected check entire first line
			let [ commented, marker_l, marker_r ] = <sid>get_commented(getline(p_start[1]), p_start[2], a:c_type)
		endif

		" perform commenting
		if visualmode() == "\<c-v>"
			" visual block selection
			" 	only consider selected range
			for lnum in range(p_start[1], p_end[1])
				call <sid>comment_line(lnum, p_start[2], p_end[2], marker_l, marker_r, !commented)
			endfor
		else
			" other visual mode
			if p_start[1] == p_end[1]
				" only consider selected range for single lines
				call <sid>comment_line(p_start[1], p_start[2], p_end[2], marker_l, marker_r, !commented)
			else
				" considere entire line for multi-line selects
				for lnum in range(p_start[1], p_end[1])
					call <sid>comment_line(lnum, 0, -1, marker_l, marker_r, !commented)
				endfor
			endif
		endif
	else
		" normal mode
		let pos = getpos('.')
		let pos[2] -= 1

		let [ commented, marker_l, marker_r ] = <sid>get_commented(getline(pos[1]), pos[2], a:c_type)

		if commented
			" consider current column when uncommenting, allowing to uncomment
			" a single block in a line containing multiple blocks
			call <sid>comment_line(pos[1], pos[2], -1, marker_l, marker_r, !commented)
		else
			" always consider entire line
			call <sid>comment_line(pos[1], 0, -1, marker_l, marker_r, !commented)
		endif
	endif
endfunction

" \brief	sexy commenting function using one block for all lines to comment
"
" \param	comment		what to do (0 = uncomment, 1 = comment)
"
" \return	none
function g:do_comment_sexy(comment)
	" check if all sexy markers are define
	if b:marker.blocks_l == "" || b:marker.blocks_r == "" || b:marker.blocks_m == ""
		echoerr "sexy markers not defined"
		return
	endif

	if a:comment
		" get selection boundaries
		let p_start = getpos("'<")
		let p_end = getpos("'>")

		" getpos() columns ranges are 1.., map them to 0..
		let p_start[2] -= 1
		let p_end[2] -= 1

		" add marker for inner lines
		for lnum in range(p_start[1], p_end[1])
			call <sid>comment_line(lnum, 0, -1, b:marker.blocks_m, "", 1)
		endfor

		" append bottom and top line
		call append(p_end[1], b:marker.blocks_r)
		call append(p_start[1] - 1, b:marker.blocks_l)
	else
		" get current line and search enclosing marker
		let lnum = line('.')
		let top = search(escape(b:marker.blocks_l, '*'), "bcnW")
		let bot = search(escape(b:marker.blocks_r, '*'), "cnW")

		" check validity
		if top == 0 || bot == 0 || top > lnum || bot < lnum
			return
		endif

		" remove inner line markers
		for lnum in range(top + 1, bot - 1)
			call <sid>comment_line(lnum, 0, -1, b:marker.blocks_m, "", 0)
		endfor

		" delete top and bottom line
		exec ":" . bot . "d"
		exec ":" . top . "d"
	endif
endfunction
"}}}

""""
"" autocommands
""""
"{{{
" update marker once buffer filetype changes
autocmd FileType *  call <sid>update_marker()
"}}}

""""
"" mappings
""""
"{{{
" general mappings
nnoremap <silent> cl :call g:do_comment('n', 'l')<cr>
nnoremap <silent> cb :call g:do_comment('n', 'b')<cr>
vnoremap <silent> cl <esc>:call g:do_comment('v', 'l')<cr>
vnoremap <silent> cb <esc>:call g:do_comment('v', 'b')<cr>

" filetype specific mappings
autocmd FileType c,cpp nnoremap <silent> cs :call g:do_comment_sexy(0)<cr>
autocmd FileType c,cpp vnoremap <silent> cs <esc>:call g:do_comment_sexy(1)<cr>
"}}}
