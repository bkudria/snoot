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

  # A Reek smell category, named (e.g. "IrresponsibleModule"). Groups
  # Smells for ranking; keys vendored-doc lookup.
  SmellType = Data.define(:name)
end
