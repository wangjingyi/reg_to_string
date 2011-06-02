exports.error = (str) ->
	throw new Error(str)
	
exports.last = (arr) ->
	arr[arr.length - 1]

exports.first = (arr) ->
	arr[0]
	
exports.range = (ch1, ch2) ->
	return [ch1] if not ch2
	return [ch2] if not ch1
	ret = []
	range = [to_int(ch1)..to_int(ch2)]
	(to_char ch for ch in range)

to_char = (i) ->
	String.fromCharCode i
	
to_int = (ch) ->
	ch.charCodeAt()
	
lower_case = "abcdefghijklmnopqrstuvwxyz"
upper_case = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
digits = "0123456789"
specials = "~`!@#$%^&*()-_+=|\\}][{\"\':;?/>.<, "
letter_pool = lower_case + upper_case + digits + specials

exports.random_char = random_char = (arr) ->
	index = Math.floor(Math.random() * arr.length)
	arr[index]
	
exports.letter = letter = ->
	random_char(lower_case + upper_case)
	
exports.digit = digit = ->
	random_char digits
	
exports.space = space = ->
	' '

exports.non_digit = ->
	letter()
	
exports.non_letter = ->
	digit()
	
exports.non_space = ->
	letter()
	
exports.exclude_char = (chars) ->
	for ch in letter_pool
		if ch not in chars
			return ch
	''
	