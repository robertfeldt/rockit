Rockit
    by Robert Feldt
    FIX (url)

== DESCRIPTION:

Rockit is a potent parser generator and gives you AST's (Abstract Syntax Tree's) which you can pattern match and pretty-print. Rockit does not distinghuish between lexing and parsing so the generated parsers are scanner-/lexer-less. The vision is to extend Rockit with more advanced compiler-related abilities including back-ends and code generation. However, currently the focus is on parsing and AST-related tasks such as transformation.

This is a preview release of the upcoming Rockit 0.9.0. It has 
*VERY LITTLE* in the form of documentation and examples so it is mainly for
*VERY INTERESTED* inidividuals who want to check out what is coming. You are
also encouraged to give feedback on the "pure-Ruby" way of specing grammars.

To keep it simple and focused, lots of stuff that will be in later versions
are not included in this release:

  * Proper memoization (à la packrat)
  * Optimization
  * Error reporting
  * Java grammar
  * Ruby grammar
  * many of the good stuff from older Rockit versions (tree pattern matching, fully automated AST generation etc)
  * GPL only on things related to generation, MIT/BSD on everything needed for
      using the generated parsers etc (as much as possible)

so *BE WARNED*... ;)

Performance will be worse than expected and there will be bugs.

If you still want to check this out I suggest you start with the example in

tests/acceptance/packrat/minibasic

which is a grammar and interpreter for a mini version of Basic.

Since you a *VERY INTERESTED* individual that are previewing this I would
really appreciate if you write down any comments/improvement/problems etc
that you have/encounter while using rockit and email them to me:

robert.feldt@gmail.com

Thanks for your interest!

== FEATURES/PROBLEMS:
  
* FIX (list of features or problems)

== SYNOPSIS:

  FIX (code sample of usage)

== REQUIREMENTS:

None!

== INSTALL:

* sudo gem install

== LICENSE:

(The MIT License)

Copyright (c) 2007 Robert Feldt

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
