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

          smell_from_reek_warning(warning)
        end
      end

      def flog_analyse(paths)
        files = PathExpander.new(paths.map(&:raw), "**/*.{rb,rake}").process
        flog = Flog.new
        flog.flog(*files)
        flog.totals.filter_map do |class_method, score|
          complexity_hit_from_flog_entry(
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
          clusters << duplication_cluster_from_flay_item(item)
        end
      end

      def smell_from_reek_warning(warning)
        lines = warning.lines
        Smell.new(
          smell_type: SmellType.new(name: warning.smell_type),
          location: Location.new(
            path: Path.new(raw: warning.source),
            line_start: lines.first,
            line_end: lines.last
          ),
          message: "#{warning.context} #{warning.message}"
        )
      end

      # Flog stores method locations as "file:line" or "file:line-line_max".
      # Returns nil when the entry is missing (e.g. main#none) so callers
      # can skip top-level expressions that lack a method-level location.
      def complexity_hit_from_flog_entry(class_method:, score:, raw_location:)
        file, range = raw_location.to_s.split(":", 2)
        return unless file && range

        line_start, = range.split("-", 2).map(&:to_i)
        ComplexityHit.new(
          location: Location.new(path: Path.new(raw: file), line_start: line_start, line_end: line_start),
          method_name: class_method,
          score: BigDecimal(score.to_s)
        )
      end

      def duplication_cluster_from_flay_item(item)
        locations = item.locations.each_with_object(Set[]) do |loc, set|
          line = loc.line
          set << Location.new(path: Path.new(raw: loc.file), line_start: line, line_end: line)
        end
        DuplicationCluster.new(signature: item.structural_hash.to_s, locations: locations)
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

      # analyse runs the three analysers in canonical order (Reek ->
      # Flog -> Flay), capturing each result as it succeeds. On the
      # first failure it returns an AnalyserFailure tagged with that
      # analyser and does not invoke the remaining ones. On full
      # success it returns a Sources bundling the three result sets.
      def analyse(paths)
        outputs = {}
        ANALYSER_PROBES.each do |tag, method|
          outputs[tag] = send(method, paths)
        rescue StandardError => error
          return AnalyserFailure.new(analyser: tag, message: error.message)
        end
        Sources.new(
          smells: outputs[:reek], complexities: outputs[:flog], duplications: outputs[:flay]
        )
      end
    end
  end
end
