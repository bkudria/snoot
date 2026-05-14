# frozen_string_literal: true

module Snoot
  # Turns a pending Run into a terminal outcome: orchestrates the three
  # analysers, then selects one finding (or none, or signals failure).
  # `invoke` returns an AnalyseRun::Result carrying the terminal Run, the
  # events emitted along the way, and the raw smell set the orchestration
  # produced.
  module AnalyseRun
    # SkippedDocLessSmellWarned carries the terminal Run and the
    # offending smell_type that lacked a vendored doc.
    SkippedDocLessSmellWarned = Data.define(:run, :smell_type)

    module_function

    def invoke(paths, orchestration:)
      run = Run.new(paths: paths, outcome: :pending)
      result = orchestration.analyse(paths)
      return analysis_failure(run, result) if result.is_a?(AnalyserFailure)

      Decision.new(orchestration: orchestration, sources: result).resolve(run)
    end

    def analysis_failure(run, failure)
      failed = run.transition_to(:analysis_failed, failure: failure)
      Result.new(run: failed, events: [], smells: Set[])
    end

    def select_top_finding(findings)
      top_smell(findings.grep(Smell)) ||
        top_duplication(findings.grep(DuplicationCluster)) ||
        top_complexity(findings.grep(ComplexityHit))
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
