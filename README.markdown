Regular expression to string

For a given regular expression, generate a string that can be matched by the given regular expression. 

Structure:

  exp.coffee       a combination of a parser and evaluator
  lexer.coffee     a tokenizer
  example.coffee   few examples

Example:

  eval = make_evaluator()
  console.log eval "abc"   
  console.log eval "abc|defg" 

you can find more examples in the example.coffee file
