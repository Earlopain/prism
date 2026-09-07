# frozen_string_literal: true

require_relative "test_helper"

return unless defined?(RubyVM::InstructionSequence)

module Prism
  class NewlineTest < TestCase
    def test_visitor
      assert_newlines(<<~'RUBY')
        class Foo
          foo do
            bar
            baz
          end

          -> do
            foo
            bar
          end

          if foo
            bar
            baz
          end

          foo if bar
          foo unless bar
          foo while bar
          foo until bar

          begin
            foo
          rescue
            bar
          ensure
            baz
          end

          foo rescue nil

          ()

          "foo
            #{}
          baz"

          `foo
            `

          /foo
            #{}
          baz/

          /foo
            #{}
          baz/

          if /foo
            #{}
          baz/ then end
        end
      RUBY
    end

    private

    def assert_newlines(source)
      expected = rubyvm_lines(source)

      result = Prism.parse(source)
      assert_empty result.errors
      actual = prism_lines(result)

      source.each_line.with_index(1) do |line, line_number|
        # Lines like `while (foo = bar)` result in two line flags in the
        # bytecode but only one newline flag in the AST. We need to remove the
        # extra line flag from the bytecode to make the test pass.
        if line.match?(/while \(/)
          index = expected.index(line_number)
          expected.delete_at(index) if index
        end

        # Lines like `foo =` where the value is on the next line result in
        # another line flag in the bytecode but only one newline flag in the
        # AST.
        if line.match?(/^\s+\w+ =$/)
          if source.lines[line_number].match?(/^\s+case/)
            actual[actual.index(line_number)] += 1
          else
            actual.delete_at(actual.index(line_number))
          end
        end

        if line.match?(/^\s+\w+ = \[$/)
          if !expected.include?(line_number) && !expected.include?(line_number + 2)
            actual[actual.index(line_number)] += 1
          end
        end
      end

      assert_equal expected, actual
    end

    def rubyvm_lines(source)
      queue = [ignore_warnings { RubyVM::InstructionSequence.compile(source) }]
      lines = []

      while iseq = queue.shift
        lines.concat(iseq.trace_points.filter_map { |line, event| line if event == :line })
        iseq.each_child { |insn| queue << insn unless insn.label.start_with?("ensure in ") }
      end

      lines.sort
    end

    def prism_lines(result)
      result.mark_newlines!

      queue = [result.value]
      newlines = []

      while node = queue.shift
        queue.concat(node.compact_child_nodes)
        newlines << result.source.line(node.location.start_offset) if node&.newline_flag?
      end

      newlines.sort
    end
  end
end
