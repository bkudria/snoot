# frozen_string_literal: true

require "flay"
require "flog"
require "path_expander"
require "reek"
require "reek/cli/options"
require "reek/configuration/app_configuration"
require "reek/source/source_locator"

module Snoot
  module AnalyserOrchestration
    # AnalyserRuns runs reek, flog and flay over a path set and returns
    # each one's raw output untranslated, so an error raised here comes
    # from the analyser or its inputs rather than from snoot's mapping.
    #
    # Directory expansion mirrors each tool's own CLI default rather than
    # imposing a snoot-wide glob, so a directory Path resolves exactly as
    # that tool would resolve it on the command line. Reek defers to
    # `Reek::Source::SourceLocator` (which also honours `.reek.yml
    # exclude_paths`); Flog uses `**/*.{rb,rake}` to match `Flog::CLI`
    # and, like it, has no way to exclude files; Flay uses `**/*.rb` and
    # drops files matched by the current directory's `.flayignore`, as
    # `Flay.run` does (Flay's CLI additionally appends extensions
    # advertised by installed Flay plugins, which snoot does not load).
    module AnalyserRuns
      FLAY_IGNORE = ".flayignore"

      module_function

      # Examiner#smells is where reek reads and parses the file, so it is
      # called here rather than left for the caller to trigger.
      def reek(paths)
        config = Reek::Configuration::AppConfiguration.from_default_path
        Reek::Source::SourceLocator.new(paths.map(&:raw), configuration: config).sources.map do |pathname|
          [pathname, Reek::Examiner.new(pathname, configuration: config).smells]
        end
      end

      def flog(paths)
        Flog.new.tap { |flog| flog.flog(*expand_paths(paths, "**/*.{rb,rake}")) }
      end

      def flay(paths)
        flay = Flay.new
        flay.process(*expand_paths(paths, "**/*.rb", ignore: FLAY_IGNORE))
        [flay, flay.analyze]
      end

      # PathExpander#process is avoided: it drops arguments that don't
      # exist and then scans "." when none remain, so flog and flay would
      # analyse a directory nobody named.
      def expand_paths(paths, glob, ignore: nil)
        raws = paths.map(&:raw)
        expander = PathExpander.new(raws, glob)
        files = expander.expand_dirs_to_files(*raws).uniq
        ignore ? expander.filter_files(files, ignore) : files
      end

      private_class_method :expand_paths
    end
  end
end
