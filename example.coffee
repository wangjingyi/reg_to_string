{make_evaluator} = require './exp'
{make_lexer} = require './lexer'

eval = make_evaluator() 
console.log eval "abc" 
console.log eval "abc|defgh"
console.log eval "a(bc|de)ghi"
console.log eval "a(bc|de){3}ghi"
console.log eval "ab+cd*(def|ghi){2, }ghi"
console.log eval "ab+cd*(def|ghi){,3}AA"
console.log eval "ab+cd*(def|ghi){1,  3}FF"
console.log eval "abc[1-9]{3}def"
console.log eval /abc/
console.log eval /abc[$[^\b\\]FF/
