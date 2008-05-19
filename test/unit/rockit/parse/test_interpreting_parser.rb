require 'test/unit'

require 'rockit/parse/pe_grammar'

class TestInterpretingParser < Test::Unit::TestCase
  def test_01_grammar_with_single_production_with_single_regexp
    g = Parse::Grammar.new do
      start_symbol :s
      prod :s, [/a+/]
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("a")
    assert_equal([:s, "a"], res1)

    res2 = ip.parse_string("aaaa")
    assert_equal([:s, "aaaa"], res2)

    res3 = ip.parse_string("b")
    assert_equal(false, res3)
  end

  def test_02_grammar_with_single_production_with_multiple_regexps
    g = Parse::Grammar.new do
      start_symbol :first
      prod :first, [/a+/, /b+/, /dc*/]
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("abbd")
    assert_equal([:first, "a", "bb", "d"], res1)    

    res2 = ip.parse_string("aaabdcc")
    assert_equal([:first, "aaa", "b", "dcc"], res2)

    res2 = ip.parse_string("aaabdcc")
    assert_equal([:first, "aaa", "b", "dcc"], res2)
  end

  def test_03_grammar_with_single_rule_with_multi_prods
    g = Parse::Grammar.new do
      start_symbol :s
      rule(:s,
           [/a+/, /b+/, /dc*/],
           [/a+/, /d+/]
           )
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("aaabdcc")
    assert_equal([:s, "aaa", "b", "dcc"], res1)

    res2 = ip.parse_string("ad")
    assert_equal([:s, "a", "d"], res2)

    res3 = ip.parse_string("abc")
    assert_equal(false, res3)
  end

  def test_04_grammar_with_single_rule_and_ref_to_one_external_prod
    g = Parse::Grammar.new do
      # Note! If we do not spec the start symbol it will use the name of
      # the first rule as the start symbol.
      rule( :s, 
            [:a, /b+/, /dc*/],
            [:a, /d+/]
            )
      prod :a, [/a+/]
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("aaabdcc")
    assert_equal([:s, [:a, "aaa"], "b", "dcc"], res1)

    res2 = ip.parse_string("ad")
    assert_equal([:s, [:a, "a"], "d"], res2)

    res3 = ip.parse_string("abc")
    assert_equal(false, res3)
  end

  def test_05_grammar_with_multi_rules
    g = Parse::Grammar.new do
      rule( :Constant,
            [:DecimalInt], 
            [:HexInt], 
            [:OctalInt]
            )
      rule :DecimalInt, [/[1-9][0-9]*[uUlL]?/]
      rule :HexInt,     [/(0x|0X)[0-9a-fA-F]+[uUlL]?/]
      prod :OctalInt,   [/0[0-7]*[uUlL]?/]
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("123L")
    assert_equal([:Constant, [:DecimalInt, "123L"]], res1)

    res2 = ip.parse_string("0xad97")
    assert_equal([:Constant, [:HexInt, "0xad97"]], res2)

    res3 = ip.parse_string("02376")
    assert_equal([:Constant, [:OctalInt, "02376"]], res3)

    res4 = ip.parse_string("xg")
    assert_equal(false, res4)
  end

  def test_06_plus
    g = Parse::Grammar.new do
      prod :s, [plus(/ab/), /c/]
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("abababc")
    assert_equal([:s, ["ab", "ab", "ab"], "c"], res1)

    res2 = ip.parse_string("c")
    assert_equal(false, res2)
  end

  def test_07_mult
    g = Parse::Grammar.new do
      prod :s, [mult(/ab/), /c/]
    end
    ip = g.interpreting_parser

    res1 = ip.parse_string("abababc")
    assert_equal([:s, ["ab", "ab", "ab"], "c"], res1)

    res2 = ip.parse_string("c")
    assert_equal([:s, [], "c"], res2)
  end

  def test_08_rep
    g = Parse::Grammar.new do
      prod :s, [rep(2, 4, /ab/), /c/]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("ababc")
    assert_equal([:s, ["ab", "ab"], "c"], r)

    r = ip.parse_string("abababc")
    assert_equal([:s, ["ab", "ab", "ab"], "c"], r)

    r = ip.parse_string("ababababc")
    assert_equal([:s, ["ab", "ab", "ab", "ab"], "c"], r)

    r = ip.parse_string("c")
    assert_equal(false, r)

    r = ip.parse_string("abc")
    assert_equal(false, r)

    r = ip.parse_string("abababababc")
    assert_equal(false, r)
  end

  def test_09_maybe
    g = Parse::Grammar.new do
      prod :s, [maybe(/ab/), /c/]
    end
    ip = g.interpreting_parser
    
    r = ip.parse_string("c")
    assert_equal([:s, nil, "c"], r)

    r = ip.parse_string("abc")
    assert_equal([:s, "ab", "c"], r)
  end

  def test_10_string_literal
    g = Parse::Grammar.new do
      prod :s, ["a*b+()", /c/]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("c")
    assert_equal(false, r)

    r = ip.parse_string("abbc")
    assert_equal(false, r)

    r = ip.parse_string("a*b+()c")
    assert_equal([:s, "a*b+()", "c"], r)
  end

  def test_11_lift
    g = Parse::Grammar.new do
      prod :s, [/a+/, /b+/, lift(1)]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("abb")
    assert_equal("bb", r)

    r = ip.parse_string("bb")
    assert_equal(false, r)
  end

  def test_12_sexpr
    g = Parse::Grammar.new do
      prod :s, [/a+/, /b+/, sexpr(:a)]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("abb")
    assert_equal([:a, "a", "bb"], r)

    r = ip.parse_string("bb")
    assert_equal(false, r)
  end

  def test_13_any_with_strings
    g = Parse::Grammar.new do
      prod :s, [/\d+/, any('+', '*', '/'), /\d+/]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("12+34")
    assert_equal([:s, "12", "+", "34"], r)

    r = ip.parse_string("5*6")
    assert_equal([:s, "5", "*", "6"], r)

    r = ip.parse_string("7/18")
    assert_equal([:s, "7", "/", "18"], r)
  end

  def test_13_any_with_prods
    g = Parse::Grammar.new do
      prod :s, [/\d+/, any(:plus, :mult, "/"), /\d+/]
      prod :plus, ["+", lift(0)]
      prod :mult, ["*", lift(0)]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("12+34")
    assert_equal([:s, "12", "+", "34"], r)

    r = ip.parse_string("5*6")
    assert_equal([:s, "5", "*", "6"], r)

    r = ip.parse_string("7/18")
    assert_equal([:s, "7", "/", "18"], r)
  end

  def test_14_maybe_with_array_arg
    g = Parse::Grammar.new do
      prod :s, [maybe(["a", "b"]), "c"]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("c")
    assert_equal([:s, nil, "c"], r)
  end

  def test_15_list
    g = Parse::Grammar.new do
      prod :s, [list("a", ",")]
    end
    ip = g.interpreting_parser

    r = ip.parse_string("")
    assert_equal([:s, []], r)

    r = ip.parse_string("a")
    assert_equal([:s, ["a"]], r)

    r = ip.parse_string("a,a")
    assert_equal([:s, ["a", "a"]], r)

    r = ip.parse_string("a,a,a")
    assert_equal([:s, ["a", "a", "a"]], r)

    r = ip.parse_string("a,a,a,a,a,a")
    assert_equal([:s, ["a", "a", "a", "a", "a", "a"]], r)
  end

  def test_16_insert_whitespace
    g = Parse::Grammar.new do
      white_space = hidden(/\s*/)
      prod :s, ["a", "b"]
      all_rules.each {|rule| rule.insert(white_space)}
    end
    ip = g.interpreting_parser

    r = ip.parse_string("ab")
    assert_equal([:s, "a", "b"], r)    

    r = ip.parse_string("a  b")
    assert_equal([:s, "a", "b"], r)    

    assert_equal(false, ip.parse_string(" ab"))    
  end
end
