# frozen_string_literal: true

module Snoot
  # AnalyseRun is the rule from snoot.allium that turns a pending Run into a
  # terminal outcome by orchestrating the three analysers and selecting one
  # finding (or none, or signalling failure). Returns [run, events].
  module AnalyseRun
    # Event is the audit record emitted during AnalyseRun: signals
    # analysis_failed (with the underlying error) or
    # skipped_doc_less_smell_warned (with the offending smell_type).
    # Carries the current Run snapshot for traceability.
    Event = Data.define(:name, :run, :smell_type, :error)

    # SourcesView wraps a Snoot::Sources value with the orchestration
    # that produced it, so downstream phases can ask for derived views
    # (`all`, `candidates`) and consult `vendored_doc?` without
    # re-threading orchestration through every helper. The underlying
    # Sources is the spec-level value type returned by
    # AnalyserOrchestration#analyse.
    SourcesView = Data.define(:sources, :orchestration) do
      def smells = sources.smells
      def complexities = sources.complexities
      def duplications = sources.duplications

      def all
        significant_smells | significant_complexities | significant_duplications
      end

      def candidates
        documented = significant_smells.select { |smell| vendored_doc(smell.smell_type) }.to_set
        documented | significant_complexities | significant_duplications
      end

      def significant_smells = orchestration.significant_smells(smells)
      def significant_complexities = orchestration.significant_complexities(complexities)
      def significant_duplications = orchestration.significant_duplications(duplications)

      def vendored_doc(smell_type)
        orchestration.vendored_doc(smell_type)
      end
    end

    module_function

    def invoke(paths, orchestration:)
      run = Run.new(paths: paths, outcome: :pending)
      result = orchestration.analyse(paths)
      return analysis_failure(run, result) if result.is_a?(AnalyserFailure)

      decide_outcome(run, SourcesView.new(sources: result, orchestration: orchestration))
    end

    def analysis_failure(run, failure)
      failed = run.transition_to(:analysis_failed, failure: failure)
      [failed, [Event.new(name: :analysis_failed, run: failed, smell_type: nil, error: nil)], Set[]]
    end

    def decide_outcome(run, sources)
      smells = sources.smells.to_set
      doc_less_smell_type = doc_less_top_smell_type(sources)
      terminal = transition(run, sources.candidates)
      [terminal, doc_less_events(terminal, doc_less_smell_type), smells]
    end

    def doc_less_top_smell_type(sources)
      top = select_top_finding(sources.all)
      return nil unless top.is_a?(Smell)

      smell_type = top.smell_type
      return nil if sources.vendored_doc(smell_type)

      smell_type
    end

    def transition(run, candidates)
      return run.transition_to(:nothing_to_report) if candidates.empty?

      run.transition_to(:finding_rendered, selected_finding: select_top_finding(candidates))
    end

    def doc_less_events(run, smell_type)
      return [] unless smell_type

      [Event.new(name: :skipped_doc_less_smell_warned, run: run, smell_type: smell_type, error: nil)]
    end

    PICKERS = [
      [Smell, :top_smell],
      [DuplicationCluster, :top_duplication],
      [ComplexityHit, :top_complexity]
    ].freeze

    def select_top_finding(findings)
      PICKERS.each do |klass, picker|
        matches = findings.grep(klass)
        return send(picker, matches) if matches.any?
      end
      nil
    end

    def top_smell(smells)
      counts = smells.group_by(&:smell_type).transform_values(&:size)
      max = counts.values.max
      smells.select { |smell| counts[smell.smell_type] == max }.min_by { |smell| smell_sort_key(smell) }
    end

    def top_duplication(clusters)
      top_by(clusters, metric: :size, &method(:duplication_sort_key))
    end

    def top_complexity(complexities)
      top_by(complexities, metric: :score, &method(:complexity_sort_key))
    end

    def top_by(items, metric:, &sort_key)
      max = items.map(&metric).max
      items.select { |item| item.public_send(metric) == max }.min_by(&sort_key)
    end

    def smell_sort_key(smell)
      type = smell.smell_type
      loc = smell.location
      [type.name, loc.path.raw, loc.line_start]
    end

    def duplication_sort_key(cluster)
      locs = cluster.locations
      [cluster.signature, locs.map { |loc| loc.path.raw }.min, locs.map(&:line_start).min]
    end

    def complexity_sort_key(hit)
      loc = hit.location
      [loc.path.raw, loc.line_start]
    end
  end
end
