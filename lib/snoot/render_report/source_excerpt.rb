# frozen_string_literal: true

module Snoot
  module RenderReport
    # The numbered code lines under a smell instance. Lines with no
    # readable text are skipped; past MAX_LINES the rest are listed by
    # number only, so a smell flagging many lines keeps the report short.
    module SourceExcerpt
      MAX_LINES = 5
      MAX_WIDTH = 160

      module_function

      def lines(source_lines)
        readable = source_lines.select(&:text)
        shown = readable.take(MAX_LINES)
        hidden = readable.drop(MAX_LINES)
        width = shown.map { |line| line.number.to_s.size }.max
        code = shown.map { |line| code_line(line, width) }
        hidden.any? ? [*code, more_line(hidden)] : code
      end

      def code_line(line, width)
        "    #{line.number.to_s.rjust(width)} | #{clip(line.text.strip)}"
      end

      def more_line(hidden)
        "    … #{hidden.size} more: #{hidden.map(&:number).join(', ')}"
      end

      def clip(text)
        text.size > MAX_WIDTH ? "#{text[0, MAX_WIDTH - 1]}…" : text
      end
    end
  end
end
