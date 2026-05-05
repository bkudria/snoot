# frozen_string_literal: true

module Snoot
  # Location is the value type from snoot.allium pinning a Finding to a
  # source range: a Path plus inclusive line_start/line_end. Used by
  # Smell, ComplexityHit, and each entry in a DuplicationCluster. Carries
  # its own report-rendering (#description) so the AnalyserOrchestration
  # contract need not.
  Location = Data.define(:path, :line_start, :line_end) do
    def description = "#{path.raw}:#{line_start}-#{line_end}"
  end
end
