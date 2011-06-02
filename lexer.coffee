{error, letter, digit, space, non_digit, non_letter, non_space} = require './helper'

make_stream = (str) ->
	stream = 
		current : 0
		length : str.length
		
		next_char : (n = 1) ->
			return -1 if @.current >= @.length
			end = if @.current + n >= @.length then @.length else @.current + n
			str.substring @.current, end
			
		prev_char : (n = 1) ->
			return -1 if @.current = 0
			str.subsring @.current - n, @.current
			
		advance : (n = 1) ->
			ret = @.next_char n
			@.current += n
			ret
			
make_token = (id, type = id, value = id) ->
	token = 
		id : id
		type : type
		value : value
		
make_token_stream = (str) ->
	stream = make_stream str
	metachar = "[\\^$.|?*+(){}"
	special_class_char = "^-]\\"
	escaped_char = "nrtaefv"
	replace_chars = "dwsDWS"
	boundary_chars = "bB"
	anchor_chars = "AZz"
	
	replace_chars = 
		d : digit
		w : letter
		s : space
		D : non_digit
		W : non_letter
		S : non_space		

	is_metachar = (ch, in_class=false) ->
		if in_class then ch in special_class_char else ch in metachar
	
	back_slash = (in_class=false)->
		next = stream.next_char()
		if is_metachar next
			stream.advance()
			make_token "\\" + next, "literal", next
		else if next in escaped_char
			stream.advance()
			make_token "\\" + next, "literal", "\\" + next
		else if next of replace_chars
			stream.advance()
			make_token "\\" + next, "literal", replace_chars[next]()
		else if /[1-9]/.test next
			stream.advance()
			make_token "\\" + next, "back_reference", parseInt(next)
		else if next in boundary_chars
			stream.advance()
			make_token "\\" + next, "boundary", (if next is 'b' then "boundary" else "negate_boundary")
		else if next in anchor_chars				  
			stream.advance()
			make_token "\\" + next, "anchor", "\\" + next
		else
			error "not supported for escaping this char '" + next + "'"
	
	lexer = 
		pushed_tokens : []
		group_matches : []
		next_token : ->
			if @.pushed_tokens.length > 0
				return @.pushed_tokens.shift()
								
			ch = stream.advance()			
			switch ch
				when -1
					make_token "(end)", "(end)", -1
				when '\\' 
					back_slash()
				when '.'
					make_token ch, 'literal', letter()
				when '^'
					make_token ch, "anchor", ch
				when '$'
					make_token ch, "anchor", ch
				when '|'
					make_token ch, "pipe", ch
				when '*', '?', '+'
					value = if ch is '*' then "star" else if '?' then "question_mark" else "plus"
					next = stream.next_char()
					if next is '?'
						stream.advance()
						make_token ch + next, "repeat", "lazy_" + value
					else
						make_token ch, "repeat", value
				when '[' 
					if stream.next_char() is '^'
						n = stream.advance()
						@.pushed_tokens.push(make_token n, "exclude", n)
						if stream.next_char() is '-'
							n = stream.advance()
							@.pushed_tokens.push(make_token n, 'literal', n)
					else if stream.next_char() is '-'
						n = stream.advance()
						@.pushed_tokens.push(make_token n, "literal", n)
						
					while (n = stream.advance()) isnt ']'
						if n is '\\' 
							@.pushed_tokens.push back_slash(true)
						else if n is '-'
							@.pushed_tokens.push(make_token n, (if stream.next_char() is ']' then "literal" else "range"), n)
						else if n is '^'
							@.pushed_tokens.push(make_token n, "literal", n)
						else if n in special_class_char
							error "special character '" + n + "' in char class need to be escaped."
						else
							@.pushed_tokens.push(make_token n, "literal", n)
					@.pushed_tokens.push(make_token n, "close_bracket", n)		
					make_token ch, "open_bracket", ch
				when '('
					if stream.next_char(2) is "?:"
						next = stream.advance 2 
						make_token ch + next, "group", "non_capture_group"
					else if stream.next_char(2) is "?>"
						next = stream.advance 2
						make_token ch + next, "group", "atomic_group"
					else if stream.next_char(2) is "?="
						next = stream.advance 2
						@.group_matches.push ["lookahead_close", "positive"]
						make_token ch + next, "lookahead", "positive"
					else if stream.next_char(2) is "?!"
						next = stream.advance 2
						@.group_matches.push ["lookahead_close", "negative"]
						make_token ch + next, "lookahead", "negative"
					else if stream.next_char(3) is "?<="
						next = stream.advance 3
						@.group_matches.push ["lookbehind_close", "positive"]
						make_token ch + next, "lookbehind", "positive"
					else if stream.next_char(3) is "?<!"
						next = stream.advance 3
						@.group_matches.push ["lookbehind_close", "negative"]
						make_token ch + next, "lookbehind", "negative"
					else
						make_token ch, "group", "capture_group"
				when ')'
					if @.group_matches.length > 0
						[type, value] = @.group_matches.pop()
						make_token ch, type, value
					else
						make_token ")", "close_group"
				when '{'
					make_token ch, "open_brace", ch
				when '}'
					next = stream.next_char()
					if next is '?'
						stream.advance()
						make_token ch + next, "close_brace", "lazy"
					else
						make_token ch, "close_brace", "gready"
				else
					make_token ch, "literal", ch
					
insert_token = (stream)->
	[cat, cat_behind_positive, cat_behind_negative, cat_ahead_positive, cat_ahead_negative] = [make_token("cat"), make_token("cat_behind_positive"), make_token("cat_behind_negative"), make_token("cat_ahead_positive"), make_token("cat_ahead_negative")]
	[in_brace, in_bracket, in_look_around] = [0, 0, 0]  # on insertion in curly brace, bracket, lookardound
	ret = []
	
	prev = ->
		ret[ret.length - 1]
	
	not_in_unit = ->
		in_brace is 0 and in_bracket is 0 and in_look_around is 0
		
	should_insert_cat = (token) ->
		case1 = token.type not in ["repeat", "pipe", "open_brace", "close_group", "boundary"] and not_in_unit()   # not insert if *, ?, +, {, ), (<=, (<!
		case2 = prev() and (prev().type not in ["group", "pipe", "boundary"])   #cat will be inserted for the first
		case1 and case2
	
	should_insert_cat_behind = (token) ->
		token.type is "lookbehind"
	
	should_insert_cat_ahead = (token) ->
		prev()?.type is "lookahead_close"
		
	while (t = stream.next_token()).type isnt "(end)"
		if should_insert_cat_ahead t
			ret.push (if prev().value is "positive" then cat_ahead_positive else cat_ahead_negative)
		else if should_insert_cat_behind t
			ret.push (if t.value is "positive" then cat_behind_positive else cat_behind_negative)
		else if should_insert_cat t
			ret.push cat
			
		ret.push t
		
		in_brace++ if t.type is "open_brace"
		in_brace-- if t.type is "close_brace"
		in_bracket++ if t.type is "open_bracket"
		in_bracket-- if t.type is "close_bracket"
		in_look_around++ if t.type in ["lookahead", "lookbehind"]
		in_look_around-- if t.type in ["lookahead_close", "lookbehind_close"]
	
	ret.push t
	ret.shift() if ret[0]?.type in ["cat", "cat_behind", "cat_ahead"]
	ret

exports.make_lexer = (str) ->
	stream = make_token_stream str
	ret = insert_token stream
	[i, len] = [0, ret.length]

	lexer = 
		next_token : ->
			if i >= len then ret[len - 1] else ret[i++]