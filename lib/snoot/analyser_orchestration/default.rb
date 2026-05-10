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
    #
    # Default's public surface is exactly the five contracted methods
    # (vendored_doc, significant_smells, significant_complexities,
    # significant_duplications, analyse). The per-analyser drivers
    # (reek_analyse, flog_analyse, flay_analyse) and the per-pathname
    # helper (reek_smells_for) are private; their behaviour is observed
    # through analyse. Pure third-party-output translation is delegated
    # to the sibling module ResultMapping.
    #
    # Per-analyser directory expansion mirrors each tool's own CLI
    # default rather than imposing a snoot-wide glob, so a directory
    # Path resolves exactly as that tool would resolve it on the command
    # line. Reek defers to `Reek::Source::SourceLocator` (which also
    # honours `.reek.yml exclude_paths`); Flog uses `**/*.{rb,rake}` to
    # match `Flog::CLI`; Flay uses `**/*.rb` (Flay's CLI additionally
    # appends extensions advertised by installed Flay plugins, which
    # snoot does not load). The orchestration contract is path-abstract
    # (snoot.allium:150), so this is implementation policy each adapter
    # owns.
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

      # Memoises vendored_doc results by smell_type.name. The corpus is
      # fixed at gem build time (DOCS_ROOT, pinned to bundled reek) and
      # the @invariant Determinism contract treats each call pure within
      # a single CLI invocation, so caching across calls within a
      # process is safe. nil (missing-doc) results are cached too.
      @vendored_doc_cache = {}

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

          ResultMapping.smell_from_reek_warning(warning)
        end
      end

      def flog_analyse(paths)
        files = PathExpander.new(paths.map(&:raw), "**/*.{rb,rake}").process
        flog = Flog.new
        flog.flog(*files)
        flog.totals.filter_map do |class_method, score|
          ResultMapping.complexity_hit_from_flog_entry(
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
          clusters << ResultMapping.duplication_cluster_from_flay_item(item)
        end
      end

      def vendored_doc(smell_type)
        @vendored_doc_cache.fetch(smell_type.name) do
          path = File.join(DOCS_ROOT, "#{smell_type.name.gsub(DOC_FILENAME_PATTERN, '\1-\2')}.md")
          @vendored_doc_cache[smell_type.name] = File.exist?(path) ? File.read(path) : nil
        end
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

      private_class_method :reek_analyse, :reek_smells_for, :flog_analyse, :flay_analyse
    end
  end
end
