# frozen_string_literal: true

return if !(RUBY_ENGINE == "ruby" && RUBY_VERSION >= "3.2.0")

require_relative "test_helper"
require "ripper"

module Prism
  class LexTest < TestCase
    def test_lex_file
      assert_nothing_raised do
        Prism.lex_file(__FILE__)
      end

      error = assert_raise Errno::ENOENT do
        Prism.lex_file("idontexist.rb")
      end

      assert_equal "No such file or directory - idontexist.rb", error.message

      assert_raise TypeError do
        Prism.lex_file(nil)
      end
    end

    def test_parse_lex
      node, tokens = Prism.parse_lex("def foo; end").value

      assert_kind_of ProgramNode, node
      assert_equal 5, tokens.length
    end

    def test_parse_lex_file
      node, tokens = Prism.parse_lex_file(__FILE__).value

      assert_kind_of ProgramNode, node
      refute_empty tokens

      error = assert_raise Errno::ENOENT do
        Prism.parse_lex_file("idontexist.rb")
      end

      assert_equal "No such file or directory - idontexist.rb", error.message

      assert_raise TypeError do
        Prism.parse_lex_file(nil)
      end
    end

    if RUBY_VERSION >= "3.3"
      def test_lex_compat
        source = "foo bar"
        prism = Prism.lex_compat(source, version: "current").value
        ripper = Ripper.lex(source)
        assert_equal(ripper, prism)
      end
    end

    def test_lex_interpolation_unterminated
      # Without trailing newline
      lexed = Prism.lex(<<~'RUBY'.strip).value
        "#{C
      RUBY
      expected = <<~'PRETTY_PRINTED'
        [[STRING_BEGIN(1,0)-(1,1)("\""), 1],
         [EMBEXPR_BEGIN(1,1)-(1,3)("\#{"), 1],
         [CONSTANT(1,3)-(1,4)("C"), 32],
         [EOF(1,4)-(1,4)(""), 1]]
      PRETTY_PRINTED

      assert_equal(expected, lexed.pretty_inspect)

      # With trailing newline
      lexed = Prism.lex(<<~'RUBY').value
        "#{C
      RUBY
      expected = <<~'PRETTY_PRINTED'
        [[STRING_BEGIN(1,0)-(1,1)("\""), 1],
         [EMBEXPR_BEGIN(1,1)-(1,3)("\#{"), 1],
         [CONSTANT(1,3)-(1,4)("C"), 32],
         [NEWLINE(1,4)-(2,0)("\n"), 1],
         [EOF(1,4)-(2,0)("\n"), 1]]
      PRETTY_PRINTED

      assert_equal(expected, lexed.pretty_inspect)
    end

    def test_lex_heredoc_unterminated
      lexed = Prism.lex("<<A+B\n\#{C").value
      expected = <<~'PRETTY_PRINTED'
        [[HEREDOC_START(1,0)-(1,3)("<<A"), 1],
         [EMBEXPR_BEGIN(2,0)-(2,2)("\#{"), 1],
         [CONSTANT(2,2)-(2,3)("C"), 32],
         [HEREDOC_END(2,3)-(2,3)(""), 2],
         [PLUS(1,3)-(1,4)("+"), 1],
         [CONSTANT(1,4)-(1,5)("B"), 16],
         [NEWLINE(1,5)-(2,0)("\n"), 1],
         [EOF(2,3)-(2,3)(""), 1]]
      PRETTY_PRINTED

      assert_equal(expected, lexed.pretty_inspect)
    end
  end
end
