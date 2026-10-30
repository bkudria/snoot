# frozen_string_literal: true

module Snoot
  module CLI
    # What an invocation cut short by an unexpected error writes: the
    # error and its backtrace on stderr, the internal_error status line
    # on stdout.
    module InternalErrorReport
      module_function

      def write(pipeline, error)
        pipeline.stderr.write("snoot: internal error: #{error.class}: #{error.message}\n",
                              *error.backtrace&.map { |frame| "  #{frame}\n" })
        pipeline.stdout.write(StatusLine.internal_error(error))
      end
    end
  end
end
