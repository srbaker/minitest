# encoding: UTF-8

require "minitest/autorun"

if defined? Encoding then
  e = Encoding.default_external
  if e != Encoding::UTF_8 then
    warn ""
    warn ""
    warn "NOTE: External encoding #{e} is not UTF-8. Tests WILL fail."
    warn "      Run tests with `RUBYOPT=-Eutf-8 rake` to avoid errors."
    warn ""
    warn ""
  end
end

SomeError = Class.new Exception

unless defined? MyModule then
  module MyModule; end
  class AnError < StandardError; include MyModule; end
end

class TestMinitestAssertions < Minitest::Test
  # do not call parallelize_me! - teardown accesses @tc._assertions
  # which is not threadsafe. Nearly every method in here is an
  # assertion test so it isn't worth splitting it out further.

  RUBY18 = !defined? Encoding

  def setup
    super

    Minitest::Test.reset

    # @tc = Minitest::Test.new "fake tc"
    @tc = self
    @zomg = "zomg ponies!" # TODO: const
    @assertion_count = 1
  end

  # def teardown
  #   assert_equal(@assertion_count, @tc.assertions,
  #                "expected #{@assertion_count} assertions to be fired during the test, not #{@tc.assertions}") if @tc.passed?
  # end

  def clean s
    s.gsub(/^ {6}/, "")
  end

  def non_verbose
    orig_verbose = $VERBOSE
    $VERBOSE = false

    yield
  ensure
    $VERBOSE = orig_verbose
  end

  def assert_triggered expected, klass = Minitest::Assertion
    e = assert_raises klass do
      yield
    end

    msg = e.message.sub(/(---Backtrace---).*/m, '\1')
    msg.gsub!(/\(oid=[-0-9]+\)/, "(oid=N)")
    msg.gsub!(/(\d\.\d{6})\d+/, '\1xxx') # normalize: ruby version, impl, platform

    assert_msg = Regexp === expected ? :assert_match : :assert_equal
    self.send assert_msg, expected, msg
  end

  def util_msg exp, act, msg = nil
    s = "Expected: #{exp.inspect}\n  Actual: #{act.inspect}"
    s = "#{msg}.\n#{s}" if msg
    s
  end

  def without_diff
    old_diff = Minitest::Assertions.diff
    Minitest::Assertions.diff = nil

    yield
  ensure
    Minitest::Assertions.diff = old_diff
  end

  def test_assert
    @assertion_count = 2

    @tc.assert_equal true, @tc.assert(true), "returns true on success"
  end

  def test_assert__triggered
    assert_triggered "Expected false to be truthy." do
      @tc.assert false
    end
  end

  def test_assert__triggered_message
    assert_triggered @zomg do
      @tc.assert false, @zomg
    end
  end

  def test_assert_empty
    @assertion_count = 2

    @tc.assert_empty []
  end

  def test_assert_empty_triggered
    @assertion_count = 2

    assert_triggered "Expected [1] to be empty." do
      @tc.assert_empty [1]
    end
  end

  def test_assert_equal
    @tc.assert_equal 1, 1
  end

  def test_assert_equal_different_collection_array_hex_invisible
    object1 = Object.new
    object2 = Object.new
    msg = "No visible difference in the Array#inspect output.
           You should look at the implementation of #== on Array or its members.
           [#<Object:0xXXXXXX>]".gsub(/^ +/, "")
    assert_triggered msg do
      @tc.assert_equal [object1], [object2]
    end
  end

  def test_assert_equal_different_collection_hash_hex_invisible
    h1, h2 = {}, {}
    h1[1] = Object.new
    h2[1] = Object.new
    msg = "No visible difference in the Hash#inspect output.
           You should look at the implementation of #== on Hash or its members.
           {1=>#<Object:0xXXXXXX>}".gsub(/^ +/, "")

    assert_triggered msg do
      @tc.assert_equal h1, h2
    end
  end

  def test_assert_equal_string_encodings
    msg = <<-EOM.gsub(/^ {10}/, "")
          --- expected
          +++ actual
          @@ -1,3 +1,3 @@
          -# encoding: UTF-8
          -#    valid: false
          +# encoding: ASCII-8BIT
          +#    valid: true
           "bad-utf8-\\xF1.txt"
          EOM

    assert_triggered msg do
      x = "bad-utf8-\xF1.txt"
      y = x.dup.force_encoding "binary" # TODO: switch to .b when 1.9 dropped
      @tc.assert_equal x, y
    end
  end unless RUBY18

  def test_assert_equal_string_encodings_both_different
    msg = <<-EOM.gsub(/^ {10}/, "")
          --- expected
          +++ actual
          @@ -1,3 +1,3 @@
          -# encoding: US-ASCII
          -#    valid: false
          +# encoding: ASCII-8BIT
          +#    valid: true
           "bad-utf8-\\xF1.txt"
          EOM

    assert_triggered msg do
      x = "bad-utf8-\xF1.txt".force_encoding "ASCII"
      y = x.dup.force_encoding "binary" # TODO: switch to .b when 1.9 dropped
      @tc.assert_equal x, y
    end
  end unless RUBY18

  def test_assert_equal_different_diff_deactivated
    skip "https://github.com/MagLev/maglev/issues/209" if maglev?

    without_diff do
      assert_triggered util_msg("haha" * 10, "blah" * 10) do
        o1 = "haha" * 10
        o2 = "blah" * 10

        @tc.assert_equal o1, o2
      end
    end
  end

  def test_assert_equal_different_hex
    c = Class.new do
      def initialize s; @name = s; end
    end

    o1 = c.new "a"
    o2 = c.new "b"
    msg = "--- expected
           +++ actual
           @@ -1 +1 @@
           -#<#<Class:0xXXXXXX>:0xXXXXXX @name=\"a\">
           +#<#<Class:0xXXXXXX>:0xXXXXXX @name=\"b\">
           ".gsub(/^ +/, "")

    assert_triggered msg do
      @tc.assert_equal o1, o2
    end
  end

  def test_assert_equal_different_hex_invisible
    o1 = Object.new
    o2 = Object.new

    msg = "No visible difference in the Object#inspect output.
           You should look at the implementation of #== on Object or its members.
           #<Object:0xXXXXXX>".gsub(/^ +/, "")

    assert_triggered msg do
      @tc.assert_equal o1, o2
    end
  end

  def test_assert_equal_different_long
    msg = "--- expected
           +++ actual
           @@ -1 +1 @@
           -\"hahahahahahahahahahahahahahahahahahahaha\"
           +\"blahblahblahblahblahblahblahblahblahblah\"
           ".gsub(/^ +/, "")

    assert_triggered msg do
      o1 = "haha" * 10
      o2 = "blah" * 10

      @tc.assert_equal o1, o2
    end
  end

  def test_assert_equal_different_long_invisible
    msg = "No visible difference in the String#inspect output.
           You should look at the implementation of #== on String or its members.
           \"blahblahblahblahblahblahblahblahblahblah\"".gsub(/^ +/, "")

    assert_triggered msg do
      o1 = "blah" * 10
      o2 = "blah" * 10
      def o1.== _
        false
      end
      @tc.assert_equal o1, o2
    end
  end

  def test_assert_equal_different_long_msg
    msg = "message.
           --- expected
           +++ actual
           @@ -1 +1 @@
           -\"hahahahahahahahahahahahahahahahahahahaha\"
           +\"blahblahblahblahblahblahblahblahblahblah\"
           ".gsub(/^ +/, "")

    assert_triggered msg do
      o1 = "haha" * 10
      o2 = "blah" * 10
      @tc.assert_equal o1, o2, "message"
    end
  end

  def test_assert_equal_different_short
    assert_triggered util_msg(1, 2) do
      @tc.assert_equal 1, 2
    end
  end

  def test_assert_equal_different_short_msg
    assert_triggered util_msg(1, 2, "message") do
      @tc.assert_equal 1, 2, "message"
    end
  end

  def test_assert_equal_different_short_multiline
    msg = "--- expected\n+++ actual\n@@ -1,2 +1,2 @@\n \"a\n-b\"\n+c\"\n"
    assert_triggered msg do
      @tc.assert_equal "a\nb", "a\nc"
    end
  end

  def test_assert_equal_unescape_newlines
    msg = <<-'EOM'.gsub(/^ {10}/, "") # NOTE single quotes on heredoc
          --- expected
          +++ actual
          @@ -1,2 +1,2 @@
          -"hello
          +"hello\n
           world"
          EOM

    assert_triggered msg do
      act = 'hello\nworld'
      exp = "hello\nworld"

      @tc.assert_equal exp, act
    end
  end

  def assert_mu_pp exp, input
    @tc.assert_equal exp, mu_pp(input)
  end

  def test_mu_pp
    @assertion_count += 4

    assert_mu_pp 42.inspect,    42
    assert_mu_pp %w[a b c].inspect,    %w[a b c]
    assert_mu_pp "\"hello world\"",    "hello world"
    assert_mu_pp "\"hello\\nworld\"",   "hello\nworld"
    assert_mu_pp "\"hello\\\\nworld\"", 'hello\nworld' # notice single quotes
  end

  def assert_mu_pp_for_diff exp, input
    @tc.assert_equal exp, mu_pp_for_diff(input)
  end

  def test_mu_pp_for_diff
    @assertion_count += 3

    assert_mu_pp_for_diff "#<Object:0xXXXXXX>", Object.new
    assert_mu_pp_for_diff "\"hello world\"",    "hello world"
    assert_mu_pp_for_diff "\"hello\nworld\"",   "hello\nworld"

    exp = "# encoding: ASCII-8BIT\n#    valid: true\n\"hello\nworld\""
    assert_mu_pp_for_diff exp, "hello\nworld".b
  end

  def test_mu_pp_for_diff_single_quotes_counter
    @assertion_count += 1

    assert_mu_pp_for_diff "\"hello\\n\nworld\"", 'hello\nworld'
    assert_mu_pp_for_diff "\"hello\nworld\"",    "hello\nworld"
  end

  def test_assert_equal_does_not_allow_lhs_nil
    if Minitest::VERSION =~ /^6/ then
      warn "Time to strip the MT5 test"

      @assertion_count += 1
      assert_triggered(/Use assert_nil if expecting nil/) do
        @tc.assert_equal nil, nil
      end
    else
      err_re = /Use assert_nil if expecting nil from .*test_minitest_\w+.rb/
      err_re = "" if $-w.nil?

      assert_output "", err_re do
        @tc.assert_equal nil, nil
      end
    end
  end

  def test_assert_equal_does_not_allow_lhs_nil_triggered
    assert_triggered "Expected: nil\n  Actual: false" do
      @tc.assert_equal nil, false
    end
  end

  def test_assert_in_delta
    @tc.assert_in_delta 0.0, 1.0 / 1000, 0.1
  end

  def test_delta_consistency
    @assertion_count = 2

    @tc.assert_in_delta 0, 1, 1

    assert_triggered "Expected |0 - 1| (1) to not be <= 1." do
      @tc.refute_in_delta 0, 1, 1
    end
  end

  def test_assert_in_delta_triggered
    x = maglev? ? "9.999999xxxe-07" : "1.0e-06"
    assert_triggered "Expected |0.0 - 0.001| (0.001) to be <= #{x}." do
      @tc.assert_in_delta 0.0, 1.0 / 1000, 0.000001
    end
  end

  def test_assert_in_epsilon
    @assertion_count = 10

    @tc.assert_in_epsilon 10_000, 9991
    @tc.assert_in_epsilon 9991, 10_000
    @tc.assert_in_epsilon 1.0, 1.001
    @tc.assert_in_epsilon 1.001, 1.0

    @tc.assert_in_epsilon 10_000, 9999.1, 0.0001
    @tc.assert_in_epsilon 9999.1, 10_000, 0.0001
    @tc.assert_in_epsilon 1.0, 1.0001, 0.0001
    @tc.assert_in_epsilon 1.0001, 1.0, 0.0001

    @tc.assert_in_epsilon(-1, -1)
    @tc.assert_in_epsilon(-10_000, -9991)
  end

  def test_epsilon_consistency
    @assertion_count = 2

    @tc.assert_in_epsilon 1.0, 1.001

    msg = "Expected |1.0 - 1.001| (0.000999xxx) to not be <= 0.001."
    assert_triggered msg do
      @tc.refute_in_epsilon 1.0, 1.001
    end
  end

  def test_assert_in_epsilon_triggered
    assert_triggered "Expected |10000 - 9990| (10) to be <= 9.99." do
      @tc.assert_in_epsilon 10_000, 9990
    end
  end

  def test_assert_in_epsilon_triggered_negative_case
    x = (RUBY18 and not maglev?) ? "0.1" : "0.100000xxx"
    y = maglev? ? "0.100000xxx" : "0.1"
    assert_triggered "Expected |-1.1 - -1| (#{x}) to be <= #{y}." do
      @tc.assert_in_epsilon(-1.1, -1, 0.1)
    end
  end

  def test_assert_includes
    @assertion_count = 2

    @tc.assert_includes [true], true
  end

  def test_assert_includes_triggered
    @assertion_count = 3

    e = @tc.assert_raises Minitest::Assertion do
      @tc.assert_includes [true], false
    end

    expected = "Expected [true] to include false."
    assert_equal expected, e.message
  end

  def test_assert_instance_of
    @tc.assert_instance_of String, "blah"
  end

  def test_assert_instance_of_triggered
    assert_triggered 'Expected "blah" to be an instance of Array, not String.' do
      @tc.assert_instance_of Array, "blah"
    end
  end

  def test_assert_kind_of
    @tc.assert_kind_of String, "blah"
  end

  def test_assert_kind_of_triggered
    assert_triggered 'Expected "blah" to be a kind of Array, not String.' do
      @tc.assert_kind_of Array, "blah"
    end
  end

  def test_assert_match
    @assertion_count = 2
    @tc.assert_match(/\w+/, "blah blah blah")
  end

  def test_assert_match_matcher_object
    @assertion_count = 2

    pattern = Object.new
    def pattern.=~ _; true end

    @tc.assert_match pattern, 5
  end

  def test_assert_match_matchee_to_str
    @assertion_count = 2

    obj = Object.new
    def obj.to_str; "blah" end

    @tc.assert_match "blah", obj
  end

  def test_assert_match_object_triggered
    @assertion_count = 2

    pattern = Object.new
    def pattern.=~ _; false end
    def pattern.inspect; "[Object]" end

    assert_triggered "Expected [Object] to match 5." do
      @tc.assert_match pattern, 5
    end
  end

  def test_assert_match_triggered
    @assertion_count = 2
    assert_triggered 'Expected /\d+/ to match "blah blah blah".' do
      @tc.assert_match(/\d+/, "blah blah blah")
    end
  end

  def test_assert_nil
    @tc.assert_nil nil
  end

  def test_assert_nil_triggered
    assert_triggered "Expected 42 to be nil." do
      @tc.assert_nil 42
    end
  end

  def test_assert_operator
    @tc.assert_operator 2, :>, 1
  end

  def test_assert_operator_bad_object
    bad = Object.new
    def bad.== _; true end

    @tc.assert_operator bad, :equal?, bad
  end

  def test_assert_operator_triggered
    assert_triggered "Expected 2 to be < 1." do
      @tc.assert_operator 2, :<, 1
    end
  end

  def test_assert_output_both
    @assertion_count = 2

    @tc.assert_output "yay", "blah" do
      print "yay"
      $stderr.print "blah"
    end
  end

  def test_assert_output_both_regexps
    @assertion_count = 4

    @tc.assert_output(/y.y/, /bl.h/) do
      print "yay"
      $stderr.print "blah"
    end
  end

  def test_assert_output_err
    @tc.assert_output nil, "blah" do
      $stderr.print "blah"
    end
  end

  def test_assert_output_neither
    @assertion_count = 0

    @tc.assert_output do
      # do nothing
    end
  end

  def test_assert_output_out
    @tc.assert_output "blah" do
      print "blah"
    end
  end

  def test_assert_output_triggered_both
    assert_triggered util_msg("blah", "blah blah", "In stderr") do
      @tc.assert_output "yay", "blah" do
        print "boo"
        $stderr.print "blah blah"
      end
    end
  end

  def test_assert_output_triggered_err
    assert_triggered util_msg("blah", "blah blah", "In stderr") do
      @tc.assert_output nil, "blah" do
        $stderr.print "blah blah"
      end
    end
  end

  def test_assert_output_triggered_out
    assert_triggered util_msg("blah", "blah blah", "In stdout") do
      @tc.assert_output "blah" do
        print "blah blah"
      end
    end
  end

  def test_assert_predicate
    @tc.assert_predicate "", :empty?
  end

  def test_assert_predicate_triggered
    assert_triggered 'Expected "blah" to be empty?.' do
      @tc.assert_predicate "blah", :empty?
    end
  end

  def test_assert_raises
    @tc.assert_raises RuntimeError do
      raise "blah"
    end
  end

  def test_assert_raises_default
    @tc.assert_raises do
      raise StandardError, "blah"
    end
  end

  def test_assert_raises_default_triggered
    e = assert_raises Minitest::Assertion do
      @tc.assert_raises do
        raise SomeError, "blah"
      end
    end

    expected = clean <<-EOM.chomp
      [StandardError] exception expected, not
      Class: <SomeError>
      Message: <\"blah\">
      ---Backtrace---
      FILE:LINE:in \`test_assert_raises_default_triggered\'
      ---------------
    EOM

    actual = e.message.gsub(/^.+:\d+/, "FILE:LINE")
    actual.gsub!(/block \(\d+ levels\) in /, "") if RUBY_VERSION >= "1.9.0"

    assert_equal expected, actual
  end

  def test_assert_raises_module
    @tc.assert_raises MyModule do
      raise AnError
    end
  end

  ##
  # *sigh* This is quite an odd scenario, but it is from real (albeit
  # ugly) test code in ruby-core:
  #
  # http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?view=rev&revision=29259

  def test_assert_raises_skip
    @assertion_count = 0

    assert_triggered "skipped", Minitest::Skip do
      @tc.assert_raises ArgumentError do
        begin
          raise "blah"
        rescue
          skip "skipped"
        end
      end
    end
  end

  def test_assert_raises_triggered_different
    e = assert_raises Minitest::Assertion do
      @tc.assert_raises RuntimeError do
        raise SyntaxError, "icky"
      end
    end

    expected = clean <<-EOM.chomp
      [RuntimeError] exception expected, not
      Class: <SyntaxError>
      Message: <\"icky\">
      ---Backtrace---
      FILE:LINE:in \`test_assert_raises_triggered_different\'
      ---------------
    EOM

    actual = e.message.gsub(/^.+:\d+/, "FILE:LINE")
    actual.gsub!(/block \(\d+ levels\) in /, "") if RUBY_VERSION >= "1.9.0"

    assert_equal expected, actual
  end

  def test_assert_raises_triggered_different_msg
    e = assert_raises Minitest::Assertion do
      @tc.assert_raises RuntimeError, "XXX" do
        raise SyntaxError, "icky"
      end
    end

    expected = clean <<-EOM
      XXX.
      [RuntimeError] exception expected, not
      Class: <SyntaxError>
      Message: <\"icky\">
      ---Backtrace---
      FILE:LINE:in \`test_assert_raises_triggered_different_msg\'
      ---------------
    EOM

    actual = e.message.gsub(/^.+:\d+/, "FILE:LINE")
    actual.gsub!(/block \(\d+ levels\) in /, "") if RUBY_VERSION >= "1.9.0"

    assert_equal expected.chomp, actual
  end

  def test_assert_raises_triggered_none
    e = assert_raises Minitest::Assertion do
      @tc.assert_raises Minitest::Assertion do
        # do nothing
      end
    end

    expected = "Minitest::Assertion expected but nothing was raised."

    assert_equal expected, e.message
  end

  def test_assert_raises_triggered_none_msg
    e = assert_raises Minitest::Assertion do
      @tc.assert_raises Minitest::Assertion, "XXX" do
        # do nothing
      end
    end

    expected = "XXX.\nMinitest::Assertion expected but nothing was raised."

    assert_equal expected, e.message
  end

  def test_assert_raises_subclass
    @tc.assert_raises StandardError do
      raise AnError
    end
  end

  def test_assert_raises_subclass_triggered
    e = assert_raises Minitest::Assertion do
      @tc.assert_raises SomeError do
        raise AnError, "some message"
      end
    end

    expected = clean <<-EOM
      [SomeError] exception expected, not
      Class: <AnError>
      Message: <\"some message\">
      ---Backtrace---
      FILE:LINE:in \`test_assert_raises_subclass_triggered\'
      ---------------
    EOM

    actual = e.message.gsub(/^.+:\d+/, "FILE:LINE")
    actual.gsub!(/block \(\d+ levels\) in /, "") if RUBY_VERSION >= "1.9.0"

    assert_equal expected.chomp, actual
  end

  def test_assert_raises_exit
    @tc.assert_raises SystemExit do
      exit 1
    end
  end

  def test_assert_raises_signals
    @tc.assert_raises SignalException do
      raise SignalException, :INT
    end
  end

  def test_assert_respond_to
    @tc.assert_respond_to "blah", :empty?
  end

  def test_assert_respond_to_triggered
    assert_triggered 'Expected "blah" (String) to respond to #rawr!.' do
      @tc.assert_respond_to "blah", :rawr!
    end
  end

  def test_assert_same
    @assertion_count = 3

    o = "blah"
    @tc.assert_same 1, 1
    @tc.assert_same :blah, :blah
    @tc.assert_same o, o
  end

  def test_assert_same_triggered
    @assertion_count = 2

    assert_triggered "Expected 2 (oid=N) to be the same as 1 (oid=N)." do
      @tc.assert_same 1, 2
    end

    s1 = "blah"
    s2 = "blah"

    assert_triggered 'Expected "blah" (oid=N) to be the same as "blah" (oid=N).' do
      @tc.assert_same s1, s2
    end
  end

  def assert_deprecated name
    dep = /DEPRECATED: #{name}. From #{__FILE__}:\d+(?::.*)?/
    dep = "" if $-w.nil?

    assert_output nil, dep do
      yield
    end
  end

  def test_assert_send
    assert_deprecated :assert_send do
      @tc.assert_send [1, :<, 2]
    end
  end

  def test_assert_send_bad
    assert_deprecated :assert_send do
      assert_triggered "Expected 1.>(*[2]) to return true." do
        @tc.assert_send [1, :>, 2]
      end
    end
  end

  def test_assert_silent
    @assertion_count = 2

    @tc.assert_silent do
      # do nothing
    end
  end

  def test_assert_silent_triggered_err
    assert_triggered util_msg("", "blah blah", "In stderr") do
      @tc.assert_silent do
        $stderr.print "blah blah"
      end
    end
  end

  def test_assert_silent_triggered_out
    @assertion_count = 2

    assert_triggered util_msg("", "blah blah", "In stdout") do
      @tc.assert_silent do
        print "blah blah"
      end
    end
  end

  def test_assert_throws
    @tc.assert_throws :blah do
      throw :blah
    end
  end

  def test_assert_throws_name_error
    @tc.assert_raises NameError do
      @tc.assert_throws :blah do
        raise NameError
      end
    end
  end

  def test_assert_throws_argument_exception
    @tc.assert_raises ArgumentError do
      @tc.assert_throws :blah do
        raise ArgumentError
      end
    end
  end

  def test_assert_throws_different
    assert_triggered "Expected :blah to have been thrown, not :not_blah." do
      @tc.assert_throws :blah do
        throw :not_blah
      end
    end
  end

  def test_assert_throws_unthrown
    assert_triggered "Expected :blah to have been thrown." do
      @tc.assert_throws :blah do
        # do nothing
      end
    end
  end

  def test_capture_io
    @assertion_count = 0

    non_verbose do
      out, err = capture_io do
        puts "hi"
        $stderr.puts "bye!"
      end

      assert_equal "hi\n", out
      assert_equal "bye!\n", err
    end
  end

  def test_capture_subprocess_io
    @assertion_count = 0

    non_verbose do
      out, err = capture_subprocess_io do
        system("echo hi")
        system("echo bye! 1>&2")
      end

      assert_equal "hi\n", out
      assert_equal "bye!", err.strip
    end
  end

  def test_class_asserts_match_refutes
    @assertion_count = 0

    methods = Minitest::Assertions.public_instance_methods
    methods.map!(&:to_s) if Symbol === methods.first

    # These don't have corresponding refutes _on purpose_. They're
    # useless and will never be added, so don't bother.
    ignores = %w[assert_output assert_raises assert_send
                 assert_silent assert_throws assert_mock]

    # These are test/unit methods. I'm not actually sure why they're still here
    ignores += %w[assert_no_match assert_not_equal assert_not_nil
                  assert_not_same assert_nothing_raised
                  assert_nothing_thrown assert_raise]

    asserts = methods.grep(/^assert/).sort - ignores
    refutes = methods.grep(/^refute/).sort - ignores

    assert_empty refutes.map { |n| n.sub(/^refute/, "assert") } - asserts
    assert_empty asserts.map { |n| n.sub(/^assert/, "refute") } - refutes
  end

  def test_flunk
    assert_triggered "Epic Fail!" do
      @tc.flunk
    end
  end

  def test_flunk_message
    assert_triggered @zomg do
      @tc.flunk @zomg
    end
  end

  def test_message
    @assertion_count = 0

    assert_equal "blah2.",         @tc.message          { "blah2" }.call
    assert_equal "blah2.",         @tc.message("")      { "blah2" }.call
    assert_equal "blah1.\nblah2.", @tc.message(:blah1)  { "blah2" }.call
    assert_equal "blah1.\nblah2.", @tc.message("blah1") { "blah2" }.call

    message = proc { "blah1" }
    assert_equal "blah1.\nblah2.", @tc.message(message) { "blah2" }.call

    message = @tc.message { "blah1" }
    assert_equal "blah1.\nblah2.", @tc.message(message) { "blah2" }.call
  end

  def test_message_message
    assert_triggered "whoops.\nExpected: 1\n  Actual: 2" do
      @tc.assert_equal 1, 2, message { "whoops" }
    end
  end

  def test_message_lambda
    assert_triggered "whoops.\nExpected: 1\n  Actual: 2" do
      @tc.assert_equal 1, 2, lambda { "whoops" }
    end
  end

  def test_message_deferred
    @assertion_count, var = 0, nil

    msg = message { var = "blah" }

    assert_nil var

    msg.call

    assert_equal "blah", var
  end

  def test_pass
    @tc.pass
  end

  def test_prints
    printer = Class.new { extend Minitest::Assertions }
    str = "test".freeze

    @tc.assert_equal '"test"', printer.mu_pp(str)
  end

  def test_refute
    @assertion_count = 2

    @tc.assert_equal false, @tc.refute(false), "returns false on success"
  end

  def test_refute_empty
    @assertion_count = 2

    @tc.refute_empty [1]
  end

  def test_refute_empty_triggered
    @assertion_count = 2

    assert_triggered "Expected [] to not be empty." do
      @tc.refute_empty []
    end
  end

  def test_refute_equal
    @tc.refute_equal "blah", "yay"
  end

  def test_refute_equal_triggered
    assert_triggered 'Expected "blah" to not be equal to "blah".' do
      @tc.refute_equal "blah", "blah"
    end
  end

  def test_refute_in_delta
    @tc.refute_in_delta 0.0, 1.0 / 1000, 0.000001
  end

  def test_refute_in_delta_triggered
    x = maglev? ? "0.100000xxx" : "0.1"
    assert_triggered "Expected |0.0 - 0.001| (0.001) to not be <= #{x}." do
      @tc.refute_in_delta 0.0, 1.0 / 1000, 0.1
    end
  end

  def test_refute_in_epsilon
    @tc.refute_in_epsilon 10_000, 9990-1
  end

  def test_refute_in_epsilon_triggered
    assert_triggered "Expected |10000 - 9990| (10) to not be <= 10.0." do
      @tc.refute_in_epsilon 10_000, 9990
      flunk
    end
  end

  def test_refute_includes
    @assertion_count = 2

    @tc.refute_includes [true], false
  end

  def test_refute_includes_triggered
    @assertion_count = 3

    e = @tc.assert_raises Minitest::Assertion do
      @tc.refute_includes [true], true
    end

    expected = "Expected [true] to not include true."
    assert_equal expected, e.message
  end

  def test_refute_instance_of
    @tc.refute_instance_of Array, "blah"
  end

  def test_refute_instance_of_triggered
    assert_triggered 'Expected "blah" to not be an instance of String.' do
      @tc.refute_instance_of String, "blah"
    end
  end

  def test_refute_kind_of
    @tc.refute_kind_of Array, "blah"
  end

  def test_refute_kind_of_triggered
    assert_triggered 'Expected "blah" to not be a kind of String.' do
      @tc.refute_kind_of String, "blah"
    end
  end

  def test_refute_match
    @assertion_count = 2
    @tc.refute_match(/\d+/, "blah blah blah")
  end

  def test_refute_match_matcher_object
    @assertion_count = 2
    @tc.refute_match Object.new, 5 # default #=~ returns false
  end

  def test_refute_match_object_triggered
    @assertion_count = 2

    pattern = Object.new
    def pattern.=~ _; true end
    def pattern.inspect; "[Object]" end

    assert_triggered "Expected [Object] to not match 5." do
      @tc.refute_match pattern, 5
    end
  end

  def test_refute_match_triggered
    @assertion_count = 2
    assert_triggered 'Expected /\w+/ to not match "blah blah blah".' do
      @tc.refute_match(/\w+/, "blah blah blah")
    end
  end

  def test_refute_nil
    @tc.refute_nil 42
  end

  def test_refute_nil_triggered
    assert_triggered "Expected nil to not be nil." do
      @tc.refute_nil nil
    end
  end

  def test_refute_predicate
    @tc.refute_predicate "42", :empty?
  end

  def test_refute_predicate_triggered
    assert_triggered 'Expected "" to not be empty?.' do
      @tc.refute_predicate "", :empty?
    end
  end

  def test_refute_operator
    @tc.refute_operator 2, :<, 1
  end

  def test_refute_operator_bad_object
    bad = Object.new
    def bad.== _; true end

    @tc.refute_operator true, :equal?, bad
  end

  def test_refute_operator_triggered
    assert_triggered "Expected 2 to not be > 1." do
      @tc.refute_operator 2, :>, 1
    end
  end

  def test_refute_respond_to
    @tc.refute_respond_to "blah", :rawr!
  end

  def test_refute_respond_to_triggered
    assert_triggered 'Expected "blah" to not respond to empty?.' do
      @tc.refute_respond_to "blah", :empty?
    end
  end

  def test_refute_same
    @tc.refute_same 1, 2
  end

  def test_refute_same_triggered
    assert_triggered "Expected 1 (oid=N) to not be the same as 1 (oid=N)." do
      @tc.refute_same 1, 1
    end
  end

  def test_skip
    @assertion_count = 0

    assert_triggered "haha!", Minitest::Skip do
      @tc.skip "haha!"
    end
  end
end