# frozen_string_literal: true

require "bigdecimal"
require "flay"
require "flog"
require "path_expander"
require "reek"
require "reek/cli/options"
require "reek/configuration/app_configuration"
require "reek/source/source_locator"

module Snoot
  module AnalyserOrchestration
    # Default is the production adapter for AnalyserOrchestration. It
    # invokes the real Reek/Flog/Flay APIs in-process (no shellouts) and
    # resolves vendored_doc against the reek docs vendored at
    # data/reek_docs/<PascalCase-Hyphen>.md (synced via `rake docs:sync`,
    # pinned to the bundled reek version). Reek invocation honours a
    # project-local `.reek.yml` (or any ancestor's, falling back to
    # `~/.reek.yml`) via `AppConfiguration.from_default_path`, matching
    # reek's own CLI discovery. Flog scoring uses Flog's default options
    # (every scored method emits a ComplexityHit; selection happens in
    # AnalyseRun). Flay duplication uses Flay's default mass threshold
    # (16). Stateless: implemented as a module of module functions, used
    # as the orchestration value directly (no `.new`).
    module Default
      DOCS_ROOT = File.expand_path("../../../data/reek_docs", __dir__).freeze
      DOC_FILENAME_PATTERN = /([a-z])([A-Z])/

      SMELL_TYPE_INSTANCE_FLOOR = 2
      COMPLEXITY_SCORE_FLOOR = BigDecimal("25")

      ANALYSER_PROBES = [
        %i[reek reek_analyse],
        %i[flog flog_analyse],
        %i[flay flay_analyse]
      ].freeze

      module_function

      def reek_analyse(paths)
        config = Reek::Configuration::AppConfiguration.from_default_path
        Reek::Source::SourceLocator.new(paths.map(&:raw), configuration: config).sources
                                   .flat_map { |pathname| reek_smells_for(pathname, config) }
                                   .to_set
      end

      def reek_smells_for(pathname, config)
        examiner = Reek::Examiner.new(pathname, configuration: config)
        examiner.smells.filter_map do |warning|
          next unless warning.lines&.any?

          Smell.from_reek_warning(warning)
        end
      end

      def flog_analyse(paths)
        files = PathExpander.new(paths.map(&:raw), "**/*.{rb,rake}").process
        flog = Flog.new
        flog.flog(*files)
        flog.totals.filter_map do |class_method, score|
          ComplexityHit.from_flog_entry(
            class_method: class_method, score: score,
            raw_location: flog.method_locations[class_method]
          )
        end.to_set
      end

      def flay_analyse(paths)
        files = PathExpander.new(paths.map(&:raw), "**/*.rb").process
        flay = Flay.new
        flay.process(*files)
        flay.analyze.each_with_object(Set[]) do |item, clusters|
          clusters << DuplicationCluster.from_flay_item(item)
        end
      end

      def vendored_doc(smell_type)
        path = File.join(DOCS_ROOT, "#{smell_type.name.gsub(DOC_FILENAME_PATTERN, '\1-\2')}.md")
        File.exist?(path) ? File.read(path) : nil
      end

      def significant_smells(smells)
        counts = smells.group_by(&:smell_type).transform_values(&:size)
        smells.select { |smell| counts[smell.smell_type] >= SMELL_TYPE_INSTANCE_FLOOR }.to_set
      end

      def significant_complexities(complexities)
        complexities.select { |hit| hit.score >= COMPLEXITY_SCORE_FLOOR }.to_set
      end

      def significant_duplications(duplications) = duplications

      # first_failure runs the three analysers in canonical order
      # (Reek -> Flog -> Flay) and returns the first AnalyserFailure
      # encountered, or nil when all three succeed. Subsequent
      # analysers are not invoked once one has failed.
      def first_failure(paths)
        ANALYSER_PROBES.each do |tag, method|
          send(method, paths)
        rescue StandardError => error
          return AnalyserFailure.new(analyser: tag, message: error.message)
        end
        nil
      end
    end
  end
end
