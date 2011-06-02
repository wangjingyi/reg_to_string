{make_lexer} = require './lexer'
{error, first, last, range, random_char, exclude_char} = require './helper'

exports.make_evaluator = () ->
	[token, lexer] = [undefined, undefined]
	symbol_table = {}
	groups = []
	
	
	original_symbol = 
		nud : ->
			error "syntax error. nud is not defined for type '" + @.type + "'"
		led : (left) ->
			error "Missing operator."
			
	expression = (rbp) ->
		t = token
		token = advance()
		left = t.nud()
		while rbp < token.lbp
			t = token
			token = advance()
			left = t.led left
		left
	
	advance = (type) ->
		if type? and token.type isnt type
			error("Expected '" + type + "', but get '" + token.type + "'")
		t = lexer.next_token()
		proto_type = symbol_table[t.type] 
		if not proto_type?
			error("Unexpected token '" + t.type + "'" )
		
		token = Object.create proto_type
		token.id = t.id
		token.value = t.value
		token
		
	make_symbol = (type, lbp=0) ->
		sym = Object.create original_symbol
		sym.type = type
		sym.lbp = lbp
		symbol_table[type] = sym
		sym
	

	make_symbol "(end)"
	make_symbol "close_group"
	make_symbol "close_brace"
	make_symbol "close_bracket"
	make_symbol "lookahead_close"
	make_symbol "lookbehind_close"
	

	lit_symbol = make_symbol "literal"
	lit_symbol.nud = ->
		@.value
	
	anchor_symbol = make_symbol "anchor"
	anchor_symbol.nud = ->
		error "anchor character can't appear in the middle of string, never match."

	boundary_symbol = make_symbol "boundary", 20
	boundary_symbol.led = (left) ->	
		negate = if @.value == "negate_boundary" then true else false		
		right = expression 20

		if negate
			if /\w/.test(last left) and /\w/.test(first right) or /\W/.test(last left) and /\W/.test(first right)
				ret = left + right
			else
				error "syntax error, non-boundary never be matched."
		else
			if /\w/.test(last left) and /\W/.test(first right) or /\W/.test(last left) and /\w/.test(first right)
				ret = left + right
			else
				error "syntax error: bounary never be matched."
		ret
					
	cat_symbol = make_symbol "cat", 20
	cat_symbol.led = (left) ->
		right = expression 20
		left + right
	
	pipe_symbol = make_symbol "pipe", 10
	pipe_symbol.led = (left) ->
		right = expression 10
		if left.length > right.length then left else right
	
	repeat_symbol = make_symbol "repeat", 30
	repeat_symbol.led = (left) ->
		left
	
	group_symbol = make_symbol "group"
	group_symbol.nud = ->
		val = expression 0
		groups.push val if @.value is "capture_group"
		advance "close_group"
		val		
	
	brace_symbol = make_symbol "open_brace", 60
	brace_symbol.led = (left)->
		tokens = []
		while token.type isnt "close_brace"
			error "expected ')'" if token.type is "(end)"
			tokens.push token
			advance()
			
		advance "close_brace"
		tokens.unshift ""
		arr = tokens.reduce((t1, t2) -> t1 + t2.id).split ','
		arr = (parseInt e for e in arr when /\S+/.test e)
		all_right_format = arr.every (e) -> not isNaN(e)
		if arr.length > 2 or not all_right_format
			error "syntax error for curly brace format repetition"
		else if arr.length == 2 and arr[0] > arr[1]
			error "syntax error the first element could not be bigger than the second one for curly brace repetition"
		
		new Array(arr[0] + 1).join left
	
	make_symbol "range"
	make_symbol "exclude"
	bracket_symbol = make_symbol "open_bracket"
	bracket_symbol.nud = ->
		if token.type is "exclude"
			advance()
			negate = true
		values = []
		while token.type isnt "close_bracket"
			if token.type is "range" 
				advance()
				[beg, end] = [last_token.value, token.value]
				last_token = token
				advance()	
								
				if beg <= end
					values = values.concat(range beg, end)
				else
					error "syntax error for range operator in character class."
			else if token.type is "literal"
				values.push token.value
				last_token = token
				advance()
			else
				error "syntax error: not allow for type '" + token.type + "' in character class."				
		advance "close_bracket"

		if values.length is 0
			error "error: character class can't be empty"
		else 
			if negate then exclude_char values else random_char values
			
	back_reference_symbol = make_symbol "back_reference"
	back_reference_symbol.nud = ->
		nth = @.value
		if nth is 0
			error "could not back reference 0 back reference"
		else if not nth
			error "the #{nth} backreference doesn't exists"
		else
			groups[nth - 1]
			
	look_behind_symbol = make_symbol "lookbehind"
	look_behind_symbol.nud = ->
		tokens = []
		while token.type isnt "lookbehind_close"
			error "expected close lookbehind => ')'" if token.type is "(end)"
			tokens.push token
			advance()
		if last(tokens).type is "anchor"
			error "anchor character '#{last(tokens).id}' can't be in the lookbehind"
		advance "lookbehind_close"
		tokens.unshift ""
		tokens.reduce((t1, t2) -> t1 + t2.id)    # need the literal string of entire lookbehind so that it can be used as a regular expression
			
	cat_behind_symbol_positive = make_symbol "cat_behind_positive", 20
	cat_behind_symbol_positive.led = (left) ->
		reg = new RegExp((expression 20) + '$')
		if reg.test left
			left
		else
			error "the lookbehind never succeed"
	
	cat_behind_symbol_negative = make_symbol "cat_behind_negative", 20
	cat_behind_symbol_negative.led = (left) ->
		reg = new RegExp((expression 20) + '$')
		if not reg.test left
			left
		else
			error "the lookbehind never succeed"
			
	look_ahead_symbol = make_symbol "lookahead"
	look_ahead_symbol.nud = ->
		tokens = []
		while token.type isnt "lookahead_close"
			error "expected close lookahead => ')'" if token.type is "(end)"
			tokens.push token
			advance()
		if first(tokens).type is "anchor"
			error "anchor character '#{first(tokens).id}' can't be in the lookahead"
		advance "lookahead_close"
		tokens.unshift ""
		tokens.reduce((t1, t2) -> t1 + t2.id)
	cat_ahead_symbol_positive = make_symbol "cat_ahead_positive", 25
	cat_ahead_symbol_positive.led = (left) ->
		reg = new RegExp('^' + left)
		value = expression 15
		if reg.test value
			value
		else
			error "the lookahead never succeed"
	
	cat_ahead_symbol_negative = make_symbol "cat_ahead_negative", 25
	cat_ahead_symbol_negative.led = (left) ->
		reg = new RegExp('^' + left)
		value = expression 15
		if not reg.test value
			value
		else
			error "the lookahead never succeed"
	
	remove_anchors = (str) ->
		str.replace(/^(\\A|\^)/, "").replace(/(\\z|\\Z|\$)$/, "")
		
	(source) -> 
		source = source.source if source instanceof RegExp
		source = remove_anchors source
		lexer = make_lexer source
		advance()
		ret = expression 0
		advance "(end)"
		ret