require "test/unit"

require "rockit/parse/pe_grammar"

# Sketches of tests for the error element

class TestError # < Test::Unit::TestCase
  def sketch_test_only_error
    g = Parse::Grammar.new do
      rule( :s,
        ["a"],
        [error()]
      )
    end
    err = g.interpreting_parser.parse_string "b"
    assert_kind_of Parse::Error, err
    assert_equal 1, err.line
    assert_equal 'Expected "a" but got "b"', err.message
  end

  def sketch_test_error_and_skip_upto
    g = Parse::Grammar.new do
      rule( :s,
        ["a"],
        [error(), skip_to(/\n/, :retry_with => :s)]
      )
    end
    p = g.interpreting_parser
    res = p.parse_string "b\na"
    assert_equal [:s, "a"], res
    errs = p.errors
    assert_kind_of Array, errs
    assert_equal 1, errs.length
    assert_kind_of Parse::Error, err[0]
    assert_equal 1, err[0].line
    assert_equal 'Expected "a" but got "b"', err[0].message
  end
end