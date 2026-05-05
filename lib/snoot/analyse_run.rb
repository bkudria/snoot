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

    module_function

    # Body mirrors the AnalyseRun rule body in snoot.allium; splitting it
    # would obscure the spec correspondence.
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def invoke(paths, orchestration:)
      run = Run.new(paths: paths, outcome: :pending)
      events = []

      smells, complexities, duplications =
        begin
          [orchestration.reek_analyse(paths),
           orchestration.flog_analyse(paths),
           orchestration.flay_analyse(paths)]
        rescue StandardError => error
          failed = run.transition_to(:analysis_failed)
          events << Event.new(name: :analysis_failed, run: failed, smell_type: nil, error: error)
          return [failed, events]
        end

      run = run.with(smells: smells.to_set)
      documented = smells.reject { |smell| orchestration.vendored_doc(smell.smell_type).nil? }
      complexities_a = complexities.to_a
      duplications_a = duplications.to_a
      candidates = documented.to_a + complexities_a + duplications_a
      all = smells.to_a + complexities_a + duplications_a

      top_overall = select_top_finding(all)
      if top_overall.is_a?(Smell)
        top_smell_type = top_overall.smell_type
        if orchestration.vendored_doc(top_smell_type).nil?
          events << Event.new(name: :skipped_doc_less_smell_warned,
                              run: run, smell_type: top_smell_type, error: nil)
        end
      end

      return [run.transition_to(:nothing_to_report), events] if candidates.empty?

      selected = select_top_finding(candidates)
      [run.transition_to(:finding_rendered, selected_finding: selected), events]
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # Tentative -- pending snoot.allium open question on cost-ranking formula.
    # Category priority: Smell > DuplicationCluster > ComplexityHit.
    def select_top_finding(findings)
      smells = findings.grep(Smell)
      return top_smell(smells) if smells.any?

      duplications = findings.grep(DuplicationCluster)
      return top_duplication(duplications) if duplications.any?

      complexities = findings.grep(ComplexityHit)
      return top_complexity(complexities) if complexities.any?

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
