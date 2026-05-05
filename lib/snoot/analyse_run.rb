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

    # Sources carries the three analyser outputs plus the orchestration
    # that produced them, so downstream phases can ask for derived
    # views (`all`, `candidates`) and consult `vendored_doc?` without
    # re-threading orchestration through every helper.
    Sources = Data.define(:smells, :complexities, :duplications, :orchestration) do
      def all
        smells.to_a + complexities.to_a + duplications.to_a
      end

      def candidates
        documented = smells.select { |smell| vendored_doc(smell.smell_type) }
        documented.to_a + complexities.to_a + duplications.to_a
      end

      def vendored_doc(smell_type)
        orchestration.vendored_doc(smell_type)
      end
    end

    module_function

    def invoke(paths, orchestration:)
      run = Run.new(paths: paths, outcome: :pending)
      sources, failure = analyse(paths, orchestration)
      return analysis_failure(run, failure) if failure

      decide_outcome(run, sources)
    end

    def analyse(paths, orchestration)
      sources = Sources.new(
        smells: orchestration.reek_analyse(paths),
        complexities: orchestration.flog_analyse(paths),
        duplications: orchestration.flay_analyse(paths),
        orchestration: orchestration
      )
      [sources, nil]
    rescue StandardError => error
      [nil, error]
    end

    def analysis_failure(run, error)
      failed = run.transition_to(:analysis_failed)
      [failed, [Event.new(name: :analysis_failed, run: failed, smell_type: nil, error: error)]]
    end

    def decide_outcome(run, sources)
      run = run.with(smells: sources.smells.to_set)
      events = doc_less_warning(run, sources)
      finalize(run, sources.candidates, events)
    end

    def doc_less_warning(run, sources)
      top = select_top_finding(sources.all)
      return [] unless top.is_a?(Smell)

      smell_type = top.smell_type
      return [] if sources.vendored_doc(smell_type)

      [Event.new(name: :skipped_doc_less_smell_warned, run: run, smell_type: smell_type, error: nil)]
    end

    def finalize(run, candidates, events)
      return [run.transition_to(:nothing_to_report), events] if candidates.empty?

      [run.transition_to(:finding_rendered, selected_finding: select_top_finding(candidates)), events]
    end

    # Tentative -- pending snoot.allium open question on cost-ranking formula.
    # Category priority: Smell > DuplicationCluster > ComplexityHit.
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
      smells.find { |smell| counts[smell.smell_type] == max }
    end

    def top_duplication(clusters)
      clusters.max_by { |cluster| cluster.locations.size }
    end

    def top_complexity(complexities)
      max_score = complexities.map(&:score).max
      complexities.find { |complexity| complexity.score == max_score }
    end
  end
end
