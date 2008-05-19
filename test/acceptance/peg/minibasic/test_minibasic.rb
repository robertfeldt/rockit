require 'test/unit'

require File.join(File.dirname(__FILE__), "minibasic")

class ATestMiniBasicParse < Test::Unit::TestCase
  def assert_parse(exp, str)
    res = MiniBasic::Parser.parse_string(str)
    assert_equal(exp, res)
  end

  def assert_stmt(expStmt, str)
    assert_parse([expStmt], str)
  end

  include MiniBasic::Grammar::ASTs

  def test_01
    assert_stmt(PrintLn[], "PRINTLN")
  end

  def test_02
    assert_stmt(Read[:A], "READ A")
  end

  def test_03
    assert_stmt(Print[:BC], "PRINT  BC")
  end

  def test_04
    assert_stmt(Assign[:D, 1], "D := 1")
    assert_stmt(Assign[:D, 1], "D :=1")
    assert_stmt(Assign[:D, 1], "D:=1")
  end

  def test_05
    assert_stmt(For[:A, 1, 3, 
                    [Assign[:S, BinExpr[:S, "+", :A]],
                     Print[:S]]], 
                "FOR A := 1 TO 3 S:= S + A PRINT S NEXT")
  end

  def test_06_if_without_else
    assert_stmt(If[Cond[3, ">", 1], [PrintLn[]], nil],
                "IF 3 > 1 THEN PRINTLN ENDIF")
  end

  def test_06_if_with_else
    assert_stmt(If[Cond[3, ">", 1], 
                   [Print[:A], PrintLn[]], 
                   [Print[:B], PrintLn[]]],
                "IF 3 > 1 THEN PRINT A PRINTLN ELSE PRINT B PRINTLN ENDIF")
  end

  def test_07_string
    assert_stmt(Assign[:A, "H"], "A := \"H\"")
  end
end

class ATestMiniBasicInterpret < Test::Unit::TestCase
  def interpret(prg, options = {})
    i = MiniBasic::Interpreter.new(options)
    ast = MiniBasic::Parser.parse_string(prg)
    res = i.interpret(ast)
    return i, res, ast
  end

  def interp(prg, options = {})
    interpret(prg, options).first
  end

  NoIndata = ("__" + rand(1e10).to_s).intern

  def test_01_assignment
    i = interp("A:=1")
    assert_equal({:A => 1}, i.vars)

    i = interp("A:=1 B := 2     C:=     3      D    :=       4")
    assert_equal({:A => 1, :B => 2, :C => 3, :D => 4}, 
                 i.vars)
  end

  def test_02_if
    i = interp("A := 1 IF A > 1 THEN A := 1 ELSE A := 0 ENDIF")
    assert_equal({:A => 0}, i.vars)

    i = interp("A := 1 IF A = 1 THEN B := 2 ELSE A := 0 ENDIF")
    assert_equal({:A => 1, :B => 2}, i.vars)
  end

  def test_03_for
    i = interp("S := 1 FOR I := 1 TO 4 S := S + I NEXT")
    assert_equal({:S => 11, :I => 4}, i.vars)
  end

  def test_04_string
    i = interp('A := "Hello World!"')
    assert_equal({:A => "Hello World!"}, i.vars)
  end

  class MockStdin
    def initialize(*lines)
      @lines, @cnt = lines, -1
    end
    def gets; @lines[(@cnt += 1)]; end
  end

  class MockStdout
    attr_reader :strs
    def initialize
      @strs = []
    end
    def print(str); @strs << str; end
    def flush; end
  end

  def test_05_read
    i = interp("READ A", :stdin => MockStdin.new("452"), 
               :stdout => (so = MockStdout.new))
    assert_equal({:A => 452}, i.vars)
    assert_equal(["? "], so.strs)
  end

  def test_06_print
    i = interp("A := 1 PRINT A", :stdout => (so = MockStdout.new))
    assert_equal({:A => 1}, i.vars)
    assert_equal(["1"], so.strs)
  end

  def test_07_println
    i = interp("PRINTLN", :stdout => (so = MockStdout.new))
    assert_equal({}, i.vars)
    assert_equal(["\n"], so.strs)
  end

  def assert_prg(filename, stdInLines, expStdoutStrs)
    fn = File.join(File.dirname(__FILE__), filename)
    prg = File.open(fn) {|fh| fh.read}
    stdout = MockStdout.new
    stdin = MockStdin.new(*stdInLines)
    i = interp(prg, :stdout => stdout, :stdin => stdin)
    assert_equal(expStdoutStrs, stdout.strs)
  end

  def assert_mult3(input, out)
    ao =
      ["What is your number", "? ", input.to_s, " * 3 = ", out.to_s, "\n"]
    assert_prg("mult3.basic", [input.to_s], ao)
  end

  def test_08_mult3
    assert_mult3(0, 0)
    assert_mult3(1, 3)
    assert_mult3(2, 6)
    assert_mult3(10, 30)
  end

  def assert_sumeven(input, out)
    ao =
      [
       "I can sum even numbers.", "\n", 
       "At what number should I start summing", "? ",
       "At what number should I stop", "? ",
       "The sum of all even numbers between (inclusive) ",
      ]
    ao << input[0].to_s
    ao << " and "
    ao << input[1].to_s
    ao << " is = "
    ao << out.to_s
    ao << "\n"
    assert_prg("sumeven.basic", input.map {|i| i.to_s}, ao)
  end

  def test_09_sumeven_program_file
    assert_sumeven([0, 1], 0)
    assert_sumeven([1, 1], 0)
    assert_sumeven([1, 4], 6)
    assert_sumeven([1, 5], 6)
    assert_sumeven([1, 6], 12)
    assert_sumeven([1, 8], 20)
    assert_sumeven([1, 10], 30)
  end
end
