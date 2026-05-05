# frozen_string_literal: true

module Snoot
  # Location is the value type from snoot.allium pinning a Finding to a
  # source range: a Path plus inclusive line_start/line_end. Used by
  # Smell, ComplexityHit, and each entry in a DuplicationCluster.
  Location = Data.define(:path, :line_start, :line_end)
end
