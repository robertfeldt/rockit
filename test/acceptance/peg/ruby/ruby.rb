#############################################################################
# Grammar for the programming language Ruby.
# Author: Robert Feldt
# based on Ruby's yacc grammar.
#############################################################################

require 'rockit/parse/pe_grammar'

module Ruby; end

Ruby::Grammar = Parse::Grammar.new do

  start_symbol :Program

  rule( :Program, [:CompoundStmt, ast(:Ruby)])

  rule( :CompoundStmt, [list(:Stmt, :TERMS), :OPT_TERM, lift(0)])

  rule( :Stmt, [:SimpleStmt, mult(:StmtModifier), ast(:Stmt)])

  rule( :SimpleStmt,
        [:Variable])

=begin
  rule( :SimpleStmt,
        ["alias", :FItem, :FItem],
        ["alias", :GVAR, :GVAR],
        ["alias", :GVAR, :BACK_REF],
        ["alias", :GVAR, :NTH_REF],
        [:UNDEF, list(:FItem, ",")],
        ["BEGIN", "{", :CompoundStmt, "}"],
        ["END", "{", :CompoundStmt, "}"],
        [:Lhs,    "=", :CommandCall],
        [:MLhs,   "=", :CommandCall],
        [:VarLhs, :OP_ASGN, :CommandCall],
        [:PrimaryValue, "[", :ArefArgs, "]", :OP_ASGN, :CommandCall],
        [:PrimaryValue, ".", :IDENTIFIER, :OP_ASGN, :CommandCall],
        [:PrimaryValue, ".", :CONSTANT, :OP_ASGN, :CommandCall],
        [:PrimaryValue, :COLON2, :IDENTIFIER, :OP_ASGN, :CommandCall],
        [:BackRef, :OP_ASGN, :CommandCall],
        [:Lhs,   "=", :MRhs],
        [:MLhs,  "=", :ArgValue],
        [:MLhs,  "=", :MRhs],
        [:Expr]
        )

  # Expr in this rule should be ExprValue and checked for special
  # conditions. Not sure what it should check for though; save this for later.
  # XXX
  rule( :StmtModifier,
        ["if",     :Expr, ast(:IfMod)],
        ["unless", :Expr, ast(:UnlessMod)],
        ["while",  :Expr, ast(:WhileMod)],
        ["until",  :Expr, ast(:UntilMod)],
        ["rescue", :Expr, ast(:RescueMod)]
        )

  rule( :Expr,
        [any(:CommandCall, 
             ["not",        :Expr,        ast(:Not)],
             ["!",          :CommandCall, ast(:NotCommand)],
             [:Arg]), 
         mult(any(["and", :Expr],
                  ["or",  :Expr]))])

  rule( :CommandCall,
        [:Command],
        [:BlockCommand],
        ["return", :CallArgs, ast(:Return)],
        ["break",  :CallArgs, ast(:Break)],
        ["next",   :CallArgs, ast(:Next)]
        )

  rule( :BlockCommand,
        [:BlockCall, maybe([any(".", "::"), :Operation2, :CommandArgs])])

  rule( :CmdBraceBlock,
        ["{", maybe(:BlockVar), :CompoundStmt, "}", ast(:CmdBraceBlock)])

  rule( :ClassDef, 
        ["class", :ID, 
#         mult(any(:Method, :AssignmentExpr)), 
         mult(:Method),
         "end"])

=end

  # We can't call it simply Method since there is already one in standard Ruby
  rule( :MethodDef,
        ["def", :FName, :ArgList, :TERM,
           :BodyStmt,
         "end", 
                            ast(:MethodDef, 1 => :name, 
                                            2 => :args, 
                                            4 => :body)])

  ID_RE = /[a-z_][a-zA-Z0-9_]*/
  #rule( :FID, [unit(ID_RE, maybe(any("!", "?"))), ast(:FID)])

  rule( :FName,
        [:FID],
        [:CONSTANT],
        [:Op])
  
  rule( :ArgList,
        ["(", :FormalArgs, ")"],
        [:FormalArgs])

  rule( :FormalArgs,
        [list(:Arg, ","), maybe([",", "*", :Arg]), maybe([",", "&", :Expr])])

  rule( :Arg, 
        [:ID, maybe(["=", :Expr, lift(1)]), 
                                            ast(:Arg, 1 => :default)])

  rule( :BodyStmt, [list(:Stmt, :TERM), 
                    maybe(["ensure", list(:Stmt, :TERM), lift(1)]), 
                    maybe(["else", list(:Stmt, :TERM), lift(1)]),
                    ast(:Body, 0 => :stmts, 1 => :ensures, 2 => :elses)
                   ]
        )

=begin
  rule( :Block,
        ["{", :CompoundStmt, "}"],
        ["do", :CompoundStmt, "end"]
        )

  rule( :StmtModifier,
        ["if",     :Expr],
        ["unless", :Expr],
        ["while",  :Expr],
        ["until",  :Expr],
        ["rescue", :Stmt]
        )

  rule( :ActualArgs,
        [list(:Expr, ","), maybe([",", "*", :Expr])],
        ["*", :Expr]
        )

  rule( :Lhs, [:Slot, maybe(["[", list(:Expr, ","), "]"])])

  rule( :MultiLhs,
        [list(:Lhs, ","), maybe([",", "*", :Expr])],
        ["*", :Lhs]
        )

  rule( :Expr, [:AssignmentExpr])

  rule( :AssignmentExpr, [list(:Primary, ","), 
                          maybe(["=", list(:Primary, ",")])])

  rule( :Primary,
        [:Slot, maybe(any(["(", :ActualArgs, ")"],
                          ["[", list(:Expr, ","), "]"],
                          [:ActualArgs]))],
        [:Aggregate]
        )

  rule( :Slot, [maybe(any([".",   any(:ID, :CONSTANT)],
                          ["::",  any(:ID, :CONSTANT)],
                          [":::", :CONSTANT]))])

  rule( :Aggregate, ["[", list(:Expr, ","), "]"])

  rule( :Atom,
        [:Variable],
        [:INT],
        [:FLOAT],
        [:DOUBLE_STRING],
        ["(", :Expr, ")"]
        )
=end

  rule( :Variable,
        [:IVAR,      lift(0)],
        [:GVAR,      lift(0)],
        [:CONSTANT,  lift(0)],
        [:CVAR,      lift(0)],
        ["nil",      ast(:Nil)],
        ["self",     ast(:Self)],
        ["true",     ast(:True)],
        ["false",    ast(:False)],
        ["__FILE__", ast(:FILE)],
        ["__LINE__", ast(:LINE)]
        )

  rule( :GVAR,     [/\$[a-zA-Z_][a-zA-Z0-9_]*/,   ast(:GVAR)])
  rule( :IVAR,     [/@[a-zA-Z_][a-zA-Z0-9_]*/,    ast(:IVAR)])
  rule( :CVAR,     [/@@[a-zA-Z_][a-zA-Z0-9_]*/,   ast(:CVAR)])
  rule( :CONSTANT, [/[A-Z][a-zA-Z0-9_]*/,         ast(:CONSTANT)])
  rule( :ID,       [ID_RE,        ast(:ID)])

  rule( :INT,           [/[0-9]+/,                     lift(0) {|s| s.to_i}])
  rule( :FLOAT,         [/\d*(\.\d+)?((e|E)-?\d+)?/,   lift(0) {|s| s.to_f}])
  rule( :DOUBLE_STRING, [/\"[^\"]*\"/])
  rule( :NL,            [/\n/])

  # Stmt termination
  rule( :TERM,      [/(;|\n)/])
  rule( :TERMS,     [/(;|\n);*/])
  rule( :OPT_TERMS, [/(;|\n)?;*/])

  # Allow whitespace in between all elements of the rules
  WhiteSpace = hidden(/( |\t)+/)
  all_rules.each {|rule| rule.insert(WhiteSpace)}
end

Ruby::Parser = Ruby::Grammar.interpreting_parser
