# PEG (Parsing Expression Grammar) parsing in Ruby.
#
require 'strscan'

module Parse; end

# A version of puts that limits output to 80 columns width
def lputs(str)
  tabs = 0
  len = (0...(str.length)).inject(0) do |l,i|
    if str[i,1] == "\t"
      tabs += 1
      l + 8
    else
      l + 1
    end
  end
  if len > 80
    s = str[0,80-3-(tabs*8)] + "..."
  else
    s = str
  end
  puts s
end

class Regexp
  def to_packrat_grammar_element
    Parse::RegexpLiteral.new(self)
  end
end

class Symbol
  # A symbol in a grammar is used to reference rules, ie by giving the name of the nonterminal (lhs of a rule).
  def to_packrat_grammar_element
    Parse::RuleRef.new(self)
  end
end

class String
  def to_packrat_grammar_element
    Parse::StringLiteral.new(self)
  end
end

class Array
  def to_packrat_grammar_element
    # An nonymous production without a name
    Parse::Production.new(nil, self)
  end
end

class Parse::GrammarElement
  def to_packrat_grammar_element; self; end
  # A GrammarElement is hidden if it does not produce a result that should
  # be used in any way. This is mostly used for whitespace.
  attr_accessor :hidden
end
 
class Parse::RegexpLiteral < Parse::GrammarElement
  def initialize(re)
    @re = re
  end
  def inspect; @re.inspect; end
end

# A StringLiteral works like a RegexpLiteral. The only reason we use
# a special class for it is so that we can inspect it in a more natural way
# (as a string instead of a Regexp).
class Parse::StringLiteral < Parse::RegexpLiteral
  attr_reader :string
  def initialize(str)
    super(Regexp.new(Regexp.escape(str)))
    @string = str
  end
  def inspect; @string.inspect; end
end

class Parse::RuleRef < Parse::GrammarElement
  attr_reader :rule_name
  def initialize(ruleName)
    @rule_name = ruleName 
  end
  def inspect; @rule_name.inspect; end
end

# A grammar Rule is a set of one or more Productions for the same
# (lhs) nonterminal. It makes an ordered choice between its productions
# by trying to parse with them in order.
class Parse::Rule
  attr_reader :name, :prods, :grammar
  def initialize(name, prods = [])
    @name, @prods = name, prods
  end
  def grammar=(grammar)
    @grammar = grammar
    @prods.each {|p| p.grammar = grammar}
  end
  def <<(prod)
    @prods << prod
  end
  def inspect
    s = "#{name.to_s} ->"
    "\n" + s + " " +
      @prods.map {|p| p.inspect(false)}.join("\n" + 
                                             " " * (s.length - 1) + "| ")
  end
end

# A grammar Production is sequence of rhs elements describing how the lhs
# symbol should be parsed.
class Parse::Production
  attr_accessor :grammar
  attr_reader :name, :rhs, :result_producer
  def initialize(name, rhs)
    @name, @rhs = name, rhs
    if Parse::ResultProducer === rhs.last
      @result_producer = @rhs.pop
    else
      # Default producer is to create a Sexpr with the production name
      # as the head of the returned array.
      @result_producer = Parse::SexprProducer.new(@name)
    end
    @rhs.map! {|e| e.to_packrat_grammar_element}
  end
  def finalize!
    @result_producer.production = self
  end
  def inspect(withLhs = true)
    rhs = @rhs.map {|e| e.hidden ? nil : e.inspect}.compact.join(' ')
    withLhs ? "#{name.to_s} -> " + rhs : rhs
  end
end

# Report results of parsing a prod or grammar element
class Parse::ErrorReporter < Parse::GrammarElement
  def initialize(sub)
    @sub = sub
  end
  def parse(parser)
    res = @sub.parse(parser)
    if false == res
      lputs "\t\t\t  FAIL #{@sub.inspect}"
      puts ""
    else
      lputs "    #{parser.pos}: Match #{@sub.inspect}"
      puts ""
    end
    res
  end
  def inspect; @sub.inspect; end
  def method_missing(method, *args)
    @sub.send(method, *args)
  end
end

module Parse::GrammarBuild
  attr_reader :start
  def start_symbol(name); @start = name; end
  def rules; @rules ||= (Hash.new {|h,k| h[k] = Parse::Rule.new(k)}); end
  def all_rules; rules.values; end
  def rule(name, *rhss)
    rhss.each {|rhs| prod(name, rhs)}
  end
  def prod(name, rhs)
    start_symbol(name) if start.nil? && !internal_name?(name)
    pr = Parse::Production.new(name, rhs)
    pr = Parse::ErrorReporter.new(pr) if $DEBUG
    rules[name] << pr
  end
  def [](name); @rules[name]; end
  def start_rule; self[self.start]; end
  def hidden(elem)
    e = elem.to_packrat_grammar_element
    e.hidden = true
    e
  end
  # Finalize the building of the grammar by conducting postprocessing.
  def finalize!
    postprocess_set_grammar_on_rules
    each_prod {|p| p.finalize!}
  end
  def postprocess_set_grammar_on_rules
    each_prod {|r| r.grammar = self}
  end
  def each_rule
    rules.values.each {|r| yield(r)}
  end
  def each_prod
    each_rule {|r| r.prods.each {|p| yield(p)}}
  end
end

class Parse::Grammar
  extend Parse::GrammarBuild

  class <<self
    def new(&grammarBuilder)
      # We must name all the sub-classes so that its AST tree classes
      # are named.
      @num_grammars ||= 0
      const_set("Grammar" + (@num_grammars += 1).to_s, 
                klass = Class.new(self))
      # Add a module to hold the AST classes
      klass.const_set("ASTs", Module.new)
      klass.module_eval(&grammarBuilder)
      klass
    end

    def interpreting_parser(klass = Parse::InterpretingParser)
      self.finalize!
      klass.new_subclass(self)
    end
  end
end

class Parse::CompoundElement < Parse::GrammarElement
  # Should save sub element(s) in @sub
end

class Parse::Repeat < Parse::CompoundElement
  def initialize(subElement, minimumReps = 0, maximumReps = false)
    @min, @max = minimumReps, maximumReps
    @sub = subElement.to_packrat_grammar_element
  end
  def inspect
    subi = @sub.inspect
    return "mult(#{subi})" if @min == 0 && @max == false
    return "plus(#{subi})" if @min == 1 && @max == false
    return "rep(@min, @max, #{subi})"
  end
end

module Parse::GrammarBuild
  def plus(element); Parse::Repeat.new(element, 1, false); end
  def mult(element); Parse::Repeat.new(element, 0, false); end
  def rep(min, max, element); Parse::Repeat.new(element, min, max); end
end

class Parse::Maybe < Parse::CompoundElement
  def initialize(sub)
    @sub = sub.to_packrat_grammar_element
  end
  def parse(parser)
    res = @sub.parse(parser)
    false == res ? nil : res
  end
  def inspect
    "(#{@sub.inspect})?"
  end
end

module Parse::GrammarBuild
  def maybe(element); Parse::Maybe.new(element); end
end

# The last element of a prod can be a result producer that produces
# the result to be returned by the prod in case of a successfull parse.
class Parse::ResultProducer
  # Before any results are produced we need to know the prod we are in
  def production=(prod); @prod = prod; end

  # A ResultProducer returns a result which it then updates. This is needed
  # since multiple results can be in production at the same time.
  def new_result(parser); end
  def update_result(res, subres, elem, index, nonHiddenIndex); res; end
  def finalize_result(res, parser); res; end
end

# Create a Sexpr based on the name of the matched production and the
# result-array.
class Parse::SexprProducer < Parse::ResultProducer
  def initialize(name)
    @name = name
  end

  def new_result(parser)
    # We do not prepend the name for anonymous productions (which have a name
    # set to nil).
    (@name == nil) ? [] : [@name]
  end
  def update_result(res, subres, elem, index, nhi); res << subres; end
end

# Lift one of the sub-results as the result from parsing a production.
# Optionally a block can be given. If so the block will get called with
# the lifted result and can modify it.
class Parse::LiftOneResultProducer < Parse::ResultProducer
  def initialize(valueIndex, &block)
    @value_index = valueIndex
    @block = block
  end
  def new_result(parser); nil; end
  def update_result(res, subres, elem, index, nonhiddenIndex)
    index == @value_index ? subres : res
  end
  def finalize_result(res, parser)
    @block ? @block.call(res) : res
  end
end

module Parse::GrammarBuild
  def sexpr(name); Parse::SexprProducer.new(name); end
  def lift(index, &b); Parse::LiftOneResultProducer.new(index, &b); end
end

module Parse::GrammarBuild
  # any() can be implemented in many ways but if all the sub-elements are
  # strings we simply create a regexp matching any of them. If they are not
  # all strings we add an internal rule with the alternatives as productions.
  def any(*subs)
    if subs.all? {|e| String === e}
      re_string = subs.map {|s| "(" + Regexp.escape(s) + ")"}.join("|")
      Parse::RegexpLiteral.new(Regexp.new(re_string))
    else
      name = internal_rule_name() 
      rule(name, *subs.map {|s| [s, lift(0)]})
      Parse::RuleRef.new(name)
    end
  end

  def next_internal_rule_num
    @internal_rule_counter ||= 0
    @internal_rule_counter += 1
  end

  InternalPrefix = "_r_"

  def internal_rule_name()
    (InternalPrefix + next_internal_rule_num.to_s).intern
  end

  def internal_name?(name)
    name.to_s =~ /#{InternalPrefix}\d+/
  end
end

class Parse::EOS < Parse::GrammarElement
  def parse(parser)
    parser.eos? ? 0 : false
  end
  def inspect; "EOS"; end
end

module Parse::GrammarBuild
  def eos(); hidden(Parse::EOS.new); end
end

# Build AST tree as result of parsing a Production.
class Parse::ASTBuilder < Parse::ResultProducer
  attr_reader :name
  def initialize(nodeName, nameMap = {})
    @name, @name_map = nodeName, nameMap
  end
  def production=(prod)
    super
    @ast_class = prod.grammar.ast_class(@name, prod, @name_map)
  end

  def new_result(parser); Array.new; end
  def update_result(res, subres, elem, index, nhIndex)
    res << subres unless @ast_class.constant_elem_at?(nhIndex)
    res
  end
  def finalize_result(res, parser)
    @ast_class.new(res, {:only_nonconstant => true})
  end
end

module Parse::GrammarBuild
  def ast(name, options = {})
    Parse::ASTBuilder.new(name, options)
  end

  # Return the ast class with the given <nodeName> for the given <production>.
  # If not previously created we create it and add it to the Tree module.
  def ast_class(name, prod, nameMap)
    acn = ast_class_name(name)
    begin
      const_get("ASTs").const_get(acn)
    rescue
      const_get("ASTs").const_set(acn, make_ast_class(acn, prod, nameMap))
    end
  end

  def ast_class_name(name)
    s = name.to_s
    s[0,1].upcase + s[1..-1]
  end

  def make_ast_class(klassName, production, nameMap)
    Parse::AST.new_subclass(klassName, production, nameMap)
  end
end

# Node in AST trees.
class Parse::AST
  class <<self
    attr_accessor :sig
    # Create a new AST subclass. The <nameMap> hash can specify names
    # for certain element indices (such explicitly specified names
    # will override the default naming scheme which is to use a downcase
    # version of the production name).
    def new_subclass(name, production, nameMap = {})
      klass = Class.new(self)
      klass.sig = extract_sig(production, nameMap)
      # Add accessor methods for all symbols in the sig
      num_strings = 0
      klass.sig.each_with_index do |sn, i|
        if Symbol === sn
          # We should subtract the num_strings in the index below
          # if we optimize this so that non-named children are never
          # added to the result array!
          klass.module_eval %{
            def #{sn.to_s}
              @children[#{i}]
            end
          }
        elsif String === sn
          num_strings += 1
        end
      end
      klass
    end

    # Return a sig for the given <production>. The sig has strings in the
    # positions where the production rhs has a String or StringLiteral,
    # has symbols in the positions where a rhs element refer to another
    # production, and has nil in other positions. The <nameMap> can contain
    # explicit names for certing indices (indices as key and name as symbol 
    # value).
    def extract_sig(production, nameMap = {})
      sig = []
      production.rhs.each_with_index do |e, i|
        unless e.hidden
          case e
          when String
            sig << e
          when Parse::StringLiteral
            sig << e.string
          when Parse::RuleRef
            sig << sub_element_name(e.rule_name)
          else
            sig << nil  # Expand this so that names are lifted out of Maybe, and "s" is added when plus and mult etc
          end
        end
      end
      number_multioccurences(sig).map {|n| nameMap[n] || n}
    end

    def number_multioccurences(sig)
      num_sigs = sig.inject(Hash.new(0)) {|h, s| h[s] += 1 if Symbol === s; h}
      counters = Hash.new(0)
      sig.map do |s|
        (num_sigs[s] > 1) ? (s.to_s + (counters[s] += 1).to_s).intern : s
      end
    end
  
    def sub_element_name(name)
      parts = name.to_s.split(/([A-Z][a-z0-9]*)/).select {|e| e.length > 0}
      parts.map {|p| p.downcase}.join("_").intern
    end

    def constant_elem_at?(index)
      self.sig[index].kind_of?(String)
    end

    def [](*args); new(args); end
  end

  DefaultOptions = {:only_nonconstant => true}

  def initialize(children, options = {})
    options = DefaultOptions.clone.update(options)
    if options[:only_nonconstant]
      @children = self.class.sig.map do |n|
        n.kind_of?(String) ? n : children.shift
      end
    else
      @children = children
    end
  end
  attr_reader :children

  def [](index); @children[index]; end

  def ==(other)
    self.class == other.class && @children == other.children
  end

  def inspect
    self.class.inspect.split("::").last + "[" +
      @children.map {|c| c.inspect}.join(", ") + "]"
  end
end

# An element which parses a list of <subElement> separated by <separator>
# element. Since this construct is so common we add an atomic element for it
# and do not translate it into other atoms.
class Parse::List < Parse::CompoundElement
  def initialize(subElement, separator = ",")
    @sub = subElement.to_packrat_grammar_element
    @separator   = separator.to_packrat_grammar_element 
  end
end

module Parse::GrammarBuild
  def list(sub, separator = ","); Parse::List.new(sub, separator); end
end

# A result producer which returns the full string matched by a production
# (and not its constituent parts).
class Parse::Map < Parse::ResultProducer
  def initialize(&block)
    @block = block
  end
  def new_result(parser)
    # We hijack the result to store the start position
    parser.pos
  end
  def finalize_result(res, parser)
    str = parser.lexeme(res, parser.pos - res)
    @block ? @block.call(str) : str
  end
end

module Parse::GrammarBuild
  def map(&b); Parse::Map.new(&b); end
end

class Parse::Rule
  def insert(elem, before = false, after = false)
    prods.each {|prod| prod.insert(elem, before, after)}
  end
end

class Parse::Production
  def inserted?; @inserted ||= false; end
  def insert(elem, before = false, after = false)
    # We only allow a single insertion!
    return nil if inserted?
    @inserted = true
    @rhs = recursive_insert(@rhs, elem, before, after)
  end
end

def recursive_insert(ary, o, before = false, after = false)
  return (before ? [o] : []) if ary.length == 0
  new_ary = before ? [o, ary.first] : [ary.first]
  ary[1..-1].each do |e| 
    new_ary << o
    new_ary << e
    e.insert(o, before, after) if e.respond_to?(:insert)
  end
  new_ary << o if after
  new_ary
end

class Parse::GrammarElement
  def insert(elem, before = false, after = false); end
end

class Parse::CompoundElement
  def insert(elem, before = false, after = false)
    if Array === @sub
      @sub = recursive_insert(@sub, elem, before, after)
    else
      @sub.insert(elem, before, after)
    end
  end
end
########################################################################
# Parsing-related 
########################################################################

class Parse::InterpretingParser
  class <<self
    attr_accessor :grammar
    def new_subclass(grammar)
      klass = Class.new(self)
      klass.grammar = grammar
      klass
    end
    def parse_string(str, startSymbol = nil)
      # We always add a whitespace since StringScanner cannot match /\s*/
      # (typically used as whitespace) at EOS
      new(str + " ").parse_string(startSymbol)
    end
  end

  attr_reader :results, :grammar

  def initialize(string)
    @str = string
    @s = StringScanner.new(string)
    @grammar = self.class.grammar
  end

  def parse_string(startSymbol = nil)
    startSymbol ||= @grammar.start
    @grammar[startSymbol].parse(self)
  end

  # Get and Set current position in string.
  def pos; @s.pos; end
  def pos=(p); @s.pos = p; end

  def eos?; @s.eos?; end

  # Extract a lexeme of length <len> from the given <pos>.
  def lexeme(pos, len)
    @str[pos, len]
  end

  # Skip using <re> at the current position in the string. Returns nil
  # if the re did not match or the length of the match if it matched.
  def skip(re)
    @s.skip(re)
  end
end

class Parse::ErrorLoggingInterpretingParser < Parse::InterpretingParser
  def skip(re)
    oldpos = pos
    r = super
    if r
      endp = pos - ((r > 0) ? 1 : 0)
      puts "#{oldpos.to_s.rjust(3)} - #{endp.to_s.ljust(3)} #{lexeme(oldpos,r).inspect} #{re.inspect}"
    else
      puts "\t\t\tNOT #{re.inspect}"
    end
    r
  end
end

class Parse::RegexpLiteral
  def parse(parser)
    oldpos = parser.pos
    len = parser.skip(@re)
    len ? parser.lexeme(oldpos, len) : false
  end
end

class Parse::Production
  def parse(parser)
    res = @result_producer.new_result(parser)
    nonhidden_index = 0
    @rhs.each_with_index do |e, i|
      subres = e.parse(parser)
      return false if false == subres
      unless e.hidden
        res = @result_producer.update_result(res, subres, e, 
                                             i, nonhidden_index)
        nonhidden_index += 1
      end
    end
    return @result_producer.finalize_result(res, parser)
  end
end

class Parse::Rule
  def parse(parser)
    oldpos = parser.pos
    prods.each do |prod|
      res = prod.parse(parser)
      return res unless false == res
      parser.pos = oldpos
    end
    return false
  end
end

class Parse::RuleRef
  def parse(parser)
    parser.grammar[@rule_name].parse(parser)
  end
end

class Parse::Repeat
  def parse(parser)
    result_list = []
    oldpos = parser.pos
    # XXX: Should we take only amx number of results here if max != false?
    while (res = @sub.parse(parser))
      result_list << res
    end
    if valid_result?(result_list)
      return result_list
    else
      parser.pos = oldpos
      return false
    end
  end
  def valid_result?(list)
    return false if @min && list.length < @min
    return false if @max && list.length > @max
    true
  end
end

class Parse::List
  def parse(parser)
    result_list = []
    res1 = @sub.parse(parser)
    if res1
      result_list << res1
      oldpos = parser.pos
      while true
        sepres = @separator.parse(parser)
        if sepres
          res = @sub.parse(parser)
          if res
            result_list << res
          else
            parser.pos = oldpos
            return result_list
          end
        else
          parser.pos = oldpos
          return result_list
        end
        oldpos = parser.pos
      end
    end
    return result_list
  end
end
