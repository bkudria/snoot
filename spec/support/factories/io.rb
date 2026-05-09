# frozen_string_literal: true

require "stringio"
require "tempfile"
require "tmpdir"

module Snoot
  module Spec
    module Factories
      def null_io
        StringIO.new
      end

      def with_ruby_tempfile(source)
        Tempfile.create(["snoot_fixture", ".rb"]) do |f|
          f.write(source)
          f.flush
          yield f.path
        end
      end

      def with_seeded_cwd(filename, source)
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write(filename, source)
            yield
          end
        end
      end
    end
  end
end
