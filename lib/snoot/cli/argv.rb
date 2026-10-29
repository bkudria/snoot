# frozen_string_literal: true

module Snoot
  module CLI
    # argv split into options and paths. An argument beginning with "-"
    # is an option unless it follows "--", which ends options and is
    # itself consumed.
    Argv = Data.define(:options, :paths) do
      def self.parse(argv)
        separator = argv.index("--")
        leading = separator ? argv.take(separator) : argv
        trailing = separator ? argv.drop(separator + 1) : []
        options, paths = leading.partition { |arg| arg.start_with?("-") }
        new(options: options, paths: paths + trailing)
      end
    end
  end
end
