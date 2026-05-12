# frozen_string_literal: true

module Snoot
  # AnalyseRun is the rule from snoot.allium that turns a pending Run into a
  # terminal outcome by orchestrating the three analysers and selecting one
  # finding (or none, or signalling failure). Returns an AnalyseRun::Result
  # value carrying the terminal Run, the audit events emitted along the way,
  # and the raw smell set the orchestration produced.
  module AnalyseRun
    # AnalysisFailed carries the terminal Run (with .failure populated).
    AnalysisFailed = Data.define(:run)

    # SkippedDocLessSmellWarned carries the terminal Run and the
    # offending smell_type that lacked a vendored doc.
    SkippedDocLessSmellWarned = Data.define(:run, :smell_type)

    module_function

    def invoke(paths, orchestration:)
      run = Run.new(paths: paths, outcome: :pending)
      result = orchestration.analyse(paths)
      return analysis_failure(run, result) if result.is_a?(AnalyserFailure)

      decide_outcome(run, result, orchestration)
    end

    def analysis_failure(run, failure)
      failed = run.transition_to(:analysis_failed, failure: failure)
      Result.new(run: failed, events: [AnalysisFailed.new(run: failed)], smells: Set[])
    end

    def decide_outcome(run, sources, orchestration)
      top_smell_overall = top_significant_smell(sources, orchestration)
      doc_less_smell_type = doc_less_smell_type_of(top_smell_overall, orchestration)
      selected = select_top_finding(candidates(sources, orchestration))
      terminal = transition(run, selected)
      Result.new(
        run: terminal,
        events: doc_less_events(terminal, doc_less_smell_type),
        smells: sources.smells
      )
    end

    def top_significant_smell(sources, orchestration)
      significant = orchestration.significant_smells(sources.smells)
      top_smell(significant) if significant.any?
    end

    def candidates(sources, orchestration)
      documented = orchestration.significant_smells(sources.smells)
                                .select { |smell| orchestration.vendored_doc(smell.smell_type) }
                                .to_set
      documented |
        orchestration.significant_complexities(sources.complexities) |
        orchestration.significant_duplications(sources.duplications)
    end

    def doc_less_smell_type_of(smell, orchestration)
      return nil unless smell
      return nil if orchestration.vendored_doc(smell.smell_type)

      smell.smell_type
    end

    def transition(run, selected)
      return run.transition_to(:nothing_to_report) if selected.nil?

      run.transition_to(:finding_rendered, selected_finding: selected)
    end

    def doc_less_events(run, smell_type)
      return [] unless smell_type

      [SkippedDocLessSmellWarned.new(run: run, smell_type: smell_type)]
    end

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
      top_by(smells, metric: ->(smell) { counts[smell.smell_type] }, &method(:smell_sort_key))
    end

    def top_duplication(clusters)
      top_by(clusters, metric: :size, &method(:duplication_sort_key))
    end

    def top_complexity(complexities)
      top_by(complexities, metric: :score, &method(:complexity_sort_key))
    end

    def top_by(items, metric:, &sort_key)
      pick = metric.to_proc
      max = items.map(&pick).max
      items.select { |item| pick.call(item) == max }.min_by(&sort_key)
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
