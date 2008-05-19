#############################################################################
# Grammar and interpreter for a mini version of Basic. 
# Author: Robert Feldt
#
# The grammar is based on the minibasic example in SableCC.
#
# Here's the copyright notice from the original file SableCC file:
#
# Copyright (C) 1997, 1998, 1999 J-Meg inc.  All rights reserved.
#
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation; either version 2.1 of the License, or
# (at your option) any later version.
#
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this file (in the file "COPYING-LESSER"); if not,
# write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307  USA
#
# If you have any question, send an electronic message to
# Etienne M. Gagnon, M.Sc. (egagnon@j-meg.com), or write to:
#
# J-Meg inc.
# 11348 Brunet
# Montreal-Nord (Quebec)
# H1G 5G1  Canada
#############################################################################
$: << "../../../../lib" if $0 == __FILE__
require 'rockit/parse/pe_grammar'

module MiniBasic
  Grammar = Parse::Grammar.new do
    start_symbol :Program

    # Spacing (S) and Forced Spacing (FS) 
    S  = hidden(/\s*/)
    FS = hidden(/\s\s*/)

    prod :Program, [S, :Statements, eos(), lift(1)]

    prod :Statements, [plus(:Statement), lift(0)]

    rule( :Statement,
          ['IF', FS, :Condition, FS, 'THEN', FS,
           :Statements, S,
           maybe(:OptElse), S,
           'ENDIF', S, ast(:If)],

          ['FOR', FS, :Identifier, S, ':=', S, :Expr, FS, 'TO', FS, :Expr, S,
           :Statements, S,
           'NEXT', S, ast(:For, :expr1 => :from, :expr2 => :to)],

          ['READ', FS, :Identifier, S, ast(:Read)],

          ['PRINTLN', S, ast(:PrintLn)],

          ['PRINT', FS, any(:Expr, :String), S, ast(:Print)],

          [:Identifier, S, ':=', S, :Expr, S, ast(:Assign)]
          )

    prod :OptElse, ['ELSE', FS, :Statements, lift(2)]

    prod :Condition, [:Expr, S, any('<', '>', '='), S, :Expr, 
                      ast(:Cond, :expr1 => :left, :expr2 => :right)]

    # This is crude! No precedence levels or handling of associativity.
    rule( :Expr,
          [:BaseExpr, S, any('+', '-', '*', '/', 'MOD'), S, :BaseExpr,
           ast(:BinExpr, :base_expr1 => :left, :base_expr2 => :right)],
          [:BaseExpr, lift(0)]
          )

    rule( :BaseExpr,
          [:Number, lift(0)],
          [:Identifier, lift(0)],
          [:String, lift(0)],
          ['(', S, :Expr, S, ')', lift(2)]
          )

    prod :String, ['"', /[^"]*/, '"', lift(1)]          #"
    prod :Identifier, [/[A-Z]([A-Z0-9])*/, lift(0) {|r| r.intern}]
    prod :Number, [/[0-9]+/, lift(0) {|r| r.to_i}]
  end

  Parser = Grammar.interpreting_parser

  class Interpreter
    attr_reader :vars

    def initialize(options = {})
      # For variables and their values. Default value is 0.
      @vars = Hash.new(0)
      @stdout = options[:stdout] || STDOUT
      @stdin = options[:stdin] || STDIN
    end

    include MiniBasic::Grammar::ASTs

    def interpret_program(str)
      ast = MiniBasic::Parser.parse_string(str)
      interpret(ast)
    end

    def interpret(ast)
      case ast
      when Array
        ast.each {|stmt| interpret(stmt)}
      when If
        if interpret(ast.condition) # What is true and false in basic?
          interpret(ast.statements)
        elsif ast[4]
          interpret(ast[4])
        end
      when For
        for i in (interpret(ast.from)..interpret(ast.to))
          @vars[ast.identifier] = i
          interpret(ast.statements)
        end
      when Read
        @stdout.print "? "
        @stdout.flush
        @vars[ast.identifier] = @stdin.gets.to_i   # Error catching?!
      when Print
        @stdout.print(interpret(ast[1]).to_s)
        @stdout.flush
      when PrintLn
        @stdout.print "\n"
        @stdout.flush
      when Assign
        @vars[ast.identifier] = interpret(ast.expr)
      when Cond
        map = {">" => :>, "<" => :<, "=" => :==}
        interpret(ast.left).send(map[ast[1]], interpret(ast.right))
      when BinExpr
        map = {"+"=>:+, "-"=>:-, "*"=>:*, "/"=>"/".intern, "MOD"=>"%".intern }
        interpret(ast.left).send(map[ast[1]], interpret(ast.right))
      when Symbol
        @vars[ast]
      else
        ast # Return the value itself
      end
    end
  end
end

if $0 == __FILE__
  prg = File.open(ARGV[0]) {|fh| fh.read}
  MiniBasic::Interpreter.new.interpret_program(prg)
end
