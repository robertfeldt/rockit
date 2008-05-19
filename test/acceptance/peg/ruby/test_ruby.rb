require 'test/unit'

require File.join(File.dirname(__FILE__), "ruby")

# We test the grammar in several logical "chunks" below with one TestCase 
# for each logical chunk.

class ATestRuby < Test::Unit::TestCase
  def assert_parse(exp, str, startSymbol, print = false)
    res = Ruby::Parser.parse_string(str, startSymbol)
    p res if print
    assert_equal(exp, res)
  end

  include Ruby::Grammar::ASTs

  def test_01_INT
    assert_parse(1,       "1", :INT)
    assert_parse(23,      "23", :INT)
    assert_parse(4567890, "4567890", :INT)
  end

  def test_02_FLOAT
    assert_parse(1.2,     "1.2",     :FLOAT)
    assert_parse(0.2345,  "0.2345",  :FLOAT)
    assert_parse(0.678,   ".678",    :FLOAT)
    assert_parse(321.4,   ".3214e3", :FLOAT)
    assert_parse(0.1,     "1e-1",    :FLOAT)
  end

  def test_03_ID
    assert_parse(ID["a"],        "a",       :ID)
    assert_parse(ID["aB91Q_T"],  "aB91Q_T", :ID)
    assert_parse(false,          "G",       :ID)
  end

  def test_03_CONSTANT
    assert_parse(CONSTANT["Ga"],        "Ga",       :CONSTANT)
    assert_parse(CONSTANT["GaB91Q_T"],  "GaB91Q_T", :CONSTANT)
    assert_parse(false,                 "1",        :CONSTANT)
    assert_parse(false,                 "a",        :CONSTANT)
  end

  def test_04_CVAR
    assert_parse(CVAR["@@a"],        "@@a",       :CVAR)
    assert_parse(CVAR["@@aB91Q_T"],  "@@aB91Q_T", :CVAR)
    assert_parse(CVAR["@@Z9"],       "@@Z9",      :CVAR)
    assert_parse(false,              "@a",        :CVAR)
  end

  def test_05_IVAR
    assert_parse(IVAR["@a"],        "@a",       :IVAR)
    assert_parse(IVAR["@aB91Q_T"],  "@aB91Q_T", :IVAR)
    assert_parse(IVAR["@Z9"],       "@Z9",      :IVAR)
    assert_parse(false,                "a",        :IVAR)
  end

  def test_06_GVAR
    assert_parse(GVAR["$a"],        "$a",       :GVAR)
    assert_parse(GVAR["$aB91Q_T"],  "$aB91Q_T", :GVAR)
    assert_parse(GVAR["$A"],        "$A",       :GVAR)
    assert_parse(GVAR["$_a"],       "$_a",      :GVAR)
    assert_parse(false,             "$9",       :GVAR)
  end

  def test_07_Variable
    assert_parse(IVAR["@iv"],   "@iv",      :Variable)
    assert_parse(GVAR["$gv"],   "$gv",      :Variable)
    assert_parse(CONSTANT["C"], "C",        :Variable)
    assert_parse(CVAR["@@cv"],  "@@cv",     :Variable)
    assert_parse(Nil[],         "nil",      :Variable)
    assert_parse(Self[],        "self",     :Variable)
    assert_parse(True[],        "true",     :Variable)
    assert_parse(False[],       "false",    :Variable)
    assert_parse(FILE[],        "__FILE__", :Variable)
    assert_parse(LINE[],        "__LINE__", :Variable)
  end

  def atest_08_fid
    assert_parse(FID["a"],        "a",       :FID)    
  end

  def atest_08_def_method
    src = <<-EOC
      def a
        true
      end
    EOC
    assert_parse MethodDef["a", [], [Stmt[True[]]]], src, :MethodDef, true
  end
end
