# frozen_string_literal: true

require "bigdecimal"

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
    # Default's public surface is exactly the six contracted methods
    # (vendored_doc, significant_smells, significant_complexities,
    # significant_duplications, significance_cutoffs, analyse). The
    # sibling module AnalyserRuns runs the analysers and returns their
    # raw output; Default's private map steps translate it, delegating
    # the pure per-item translation to the sibling module ResultMapping.
    module Default
      DOCS_ROOT = File.expand_path("../../../data/reek_docs", __dir__).freeze
      DOC_FILENAME_PATTERN = /([a-z])([A-Z])/

      SMELL_TYPE_INSTANCE_FLOOR = 2
      COMPLEXITY_SCORE_FLOOR = BigDecimal("25")

      # Each analyser's AnalyserRuns method, keyed by tag, paired with the
      # map step that translates its raw output.
      ANALYSERS = {
        reek: :smells_from_reek,
        flog: :complexities_from_flog,
        flay: :duplications_from_flay
      }.freeze

      # Memoises vendored_doc results by smell_type.name. The corpus is
      # fixed at gem build time (DOCS_ROOT, pinned to bundled reek) and
      # the @invariant Determinism contract treats each call pure within
      # a single CLI invocation, so caching across calls within a
      # process is safe. nil (missing-doc) results are cached too.
      @vendored_doc_cache = {}

      module_function

      def smells_from_reek(warnings_by_file)
        warnings_by_file.flat_map { |pathname, warnings| smells_for(pathname, warnings) }.to_set
      end

      def smells_for(pathname, warnings)
        file_lines = read_source_lines(pathname)
        warnings.filter_map do |warning|
          next unless warning.lines&.any?

          ResultMapping.smell_from_reek_warning(warning, file_lines)
        end
      end

      def read_source_lines(pathname)
        File.binread(pathname).force_encoding(Encoding::UTF_8).scrub.lines(chomp: true)
      rescue SystemCallError
        nil
      end

      def complexities_from_flog(flog)
        file_lines = Hash.new { |cache, file| cache[file] = read_source_lines(file) }
        flog.totals.filter_map { |method, score| complexity_hit_for(flog, method, score, file_lines) }.to_set
      end

      def complexity_hit_for(flog, class_method, score, file_lines)
        raw_location = flog.method_locations[class_method]
        ResultMapping.complexity_hit_from_flog_entry(
          class_method:, score:, raw_location:, calls: flog.calls[class_method],
          file_lines: raw_location && file_lines[raw_location.split(":", 2).first]
        )
      end

      def duplications_from_flay((flay, items))
        file_lines = Hash.new { |cache, file| cache[file] = read_source_lines(file) }
        items.to_set do |item|
          ResultMapping.duplication_cluster_from_flay_item(item, nodes: flay.hashes[item.structural_hash], file_lines:)
        end
      end

      def vendored_doc(smell_type)
        name = smell_type.name
        @vendored_doc_cache.fetch(name) do
          path = File.join(DOCS_ROOT, "#{name.gsub(DOC_FILENAME_PATTERN, '\1-\2')}.md")
          @vendored_doc_cache[name] = File.exist?(path) ? File.read(path) : nil
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

      def significance_cutoffs
        SignificanceCutoffs.new(
          smell_type_instances: SMELL_TYPE_INSTANCE_FLOOR,
          complexity_score: COMPLEXITY_SCORE_FLOOR,
          duplication_locations: nil
        )
      end

      # analyse runs the three analysers in canonical order (Reek ->
      # Flog -> Flay), capturing each result as it succeeds. On the
      # first analyser failure it returns an AnalyserFailure tagged with
      # that analyser and does not invoke the remaining ones. On full
      # success it returns a Sources bundling the three result sets.
      def analyse(paths)
        outputs = collect_outputs(paths)
        return outputs if outputs.is_a?(AnalyserFailure)

        Sources.new(
          smells: outputs[:reek], complexities: outputs[:flog], duplications: outputs[:flay]
        )
      end

      def collect_outputs(paths)
        ANALYSERS.each_with_object({}) do |(tag, map), outputs|
          output = run_analyser(tag, paths)
          return output if output.is_a?(AnalyserFailure)

          outputs[tag] = send(map, output)
        end
      end

      # Only the analyser's own run is an analyser failure; an error while
      # mapping its output is a bug in snoot, so it propagates.
      def run_analyser(tag, paths)
        AnalyserRuns.public_send(tag, paths)
      rescue StandardError => error
        AnalyserFailure.new(analyser: tag, message: FailureMessage.for(error))
      end

      private_class_method :smells_from_reek, :smells_for, :complexities_from_flog, :complexity_hit_for,
                           :duplications_from_flay, :collect_outputs, :run_analyser
    end
  end
end
