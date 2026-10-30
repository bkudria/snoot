# frozen_string_literal: true

module Snoot
  # Value-type wrappers: no lifecycle, equal by value.

  # A raw filesystem path string. Distinct from String so path-typed
  # slots stay traceable.
  Path = Data.define(:raw)

  # A source range: inclusive line_start/line_end at a Path. Used by
  # Smell, ComplexityHit, and each DuplicationCluster entry; carries its
  # own #description so the AnalyserOrchestration contract need not.
  Location = Data.define(:path, :line_start, :line_end) do
    def description = "#{path.raw}:#{line_start}-#{line_end}"
  end

  # One analyser-flagged line and its source text; text is nil when the
  # source file could not be read.
  SourceLine = Data.define(:number, :text)

  # A Reek smell category, named (e.g. "IrresponsibleModule"). Groups
  # Smells for ranking; keys vendored-doc lookup.
  SmellType = Data.define(:name)

  # The thresholds an orchestration's significance pre-filters apply. A
  # nil field means that category has no cutoff.
  SignificanceCutoffs = Data.define(:smell_type_instances, :complexity_score, :duplication_locations)

  # Per-category counts of significant, renderable findings a run left
  # unreported, plus the smell types still below the significance cutoff.
  # Smells count by smell type.
  RemainingFindings = Data.define(:smell_types, :duplication_clusters, :complexity_hits, :below_cutoff_smell_types)
end
