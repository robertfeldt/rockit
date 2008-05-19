require 'test/unit'

require 'rockit/parse/pe_grammar'
include Parse

class TestAST < Test::Unit::TestCase
  def setup
    @g1 = Parse::Grammar.new do
      start_symbol :s

      s  = hidden(/\s*/)
      fs = hidden(/\s\s*/)

      rule(:s, 
           ["P",  ast(:P)],
           ["S2a", :Num, :Num, ast(:S2a)],
           ["S2b", :Num, :Num, ast(:S2b, :num1 => :n1)],
           ["S2c", :Num, :Num, ast(:S2c, :num2 => :n2)],
           ["S2d", :Num, :Num, ast(:S2d, :num1 => :n1, :num2 => :n2)],
           ['FOR', fs, :Ident, s, ':=', s, :Expr, fs, 'TO', fs, :Expr, s,
            :Statements, s,
            'NEXT', s, ast(:For, :expr1 => :from, :expr2 => :to)],
           [:Num, lift(0)],
           [:Id,  lift(0)]
           )

      prod :Num, [/\d{1,2}/, ast(:Num)]
      prod :Id,  ["ID", :Num, maybe("?"), ast(:Id)]

      prod :Statements, [plus(:s), lift(0)]
      prod :Ident, [/[A-Z]([A-Z0-9])*/, lift(0) {|r| r.intern}]
      prod :Expr, [any(:Num, :Ident), lift(0)]
    end

    @ip = @g1.interpreting_parser
    @mAst = @g1::ASTs
  end
  
  def test_01_ast_module_and_classes_initialized_after_grammar_finalization
    @g1.finalize!

    assert(@g1.constants.include?("ASTs"))
    assert_kind_of(Module, @mAst)    

    expected_ast_names = ["P", "Num", "Id", "For", "S2a", "S2b", "S2c", "S2d"]
    assert_equal(expected_ast_names.sort, @mAst.constants.sort)
    expected_ast_names.each do |exp_ast_name|
      ast = @mAst.const_get(exp_ast_name)
      assert(Parse::AST, ast.superclass)
      assert_kind_of(ast, ast[])
    end

    assert_equal(["P"], @mAst::P.sig)
    assert_equal([nil], @mAst::Num.sig)
    assert_equal(["ID", :num, nil], @mAst::Id.sig)
    assert_equal(["S2a", :num1, :num2], @mAst::S2a.sig)
    assert_equal(["S2b", :n1, :num2], @mAst::S2b.sig)
    assert_equal(["S2c", :num1, :n2], @mAst::S2c.sig)
    assert_equal(["S2d", :n1, :n2], @mAst::S2d.sig)
    assert_equal(["FOR", :ident, ":=", :from, "TO", :to,
                  :statements, "NEXT"],
                 @mAst::For.sig)
  end

  def test_02_ast_parsing_no_nonconst_children
    r = @ip.parse_string("P")
    assert_equal(@mAst::P[], r)
    assert_equal("P", r[0])
  end

  def test_03_ast_parsing_single_nonconst_child
    r = @ip.parse_string("1")
    assert_equal(@mAst::Num["1"], r)
    assert_equal("1", r[0])
  end

  def test_04_ast_parsing_multi_mixed_children_default_naming
    r = @ip.parse_string("ID10")
    assert_equal('Id["ID", Num["10"], nil]', r.inspect)
    assert_equal(@mAst::Id[@mAst::Num["10"]], r)
    assert_equal(@mAst::Num["10"], r[1])
    assert_equal("ID", r[0])
    assert_equal("10", r[1][0])
    assert_equal(nil,  r[2])
    assert_equal("10", r.num[0])
  end

  def test_05_multi_mixed_overlapping_symbol_names
    r = @ip.parse_string("S2a112")
    assert_equal(@mAst::S2a[@mAst::Num["11"], @mAst::Num["2"]], r)
    assert_equal(@mAst::Num["11"], r[1])
    assert_equal(@mAst::Num["2"], r[2])
    assert_equal(@mAst::Num["11"], r.num1)
    assert_equal(@mAst::Num["2"], r.num2)
  end

  def test_06_multi_mixed_overlapping_symbol_names_with_override
    r = @ip.parse_string("S2b1134")
    assert_equal(@mAst::Num["11"], r.n1)
    assert_equal(@mAst::Num["34"], r.num2)

    r = @ip.parse_string("S2c1134")
    assert_equal(@mAst::Num["11"], r.num1)
    assert_equal(@mAst::Num["34"], r.n2)

    r = @ip.parse_string("S2d7465")
    assert_equal(@mAst::Num["74"], r.n1)
    assert_equal(@mAst::Num["65"], r.n2)
  end

  def test_07_complex_ast_parsing
    r = @ip.parse_string("FOR A := 1 TO 3 P NEXT")
    assert_equal(@mAst::For[:A, @mAst::Num["1"], @mAst::Num["3"],
                            [@mAst::P[]]], r)
  end
end
