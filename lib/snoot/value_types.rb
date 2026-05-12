# frozen_string_literal: true

module Snoot
  # Value types from snoot.allium "Value Types" section: scalar/struct
  # wrappers used to type the spec's slots. They have no lifecycle --
  # constructed as needed, equal by value.

  # Path is the value type from snoot.allium wrapping a raw filesystem
  # path string supplied to a Run. Kept distinct from String so the
  # spec's path-typed slots stay traceable.
  Path = Data.define(:raw)

  # Location is the value type from snoot.allium pinning a Finding to a
  # source range: a Path plus inclusive line_start/line_end. Used by
  # Smell, ComplexityHit, and each entry in a DuplicationCluster. Carries
  # its own report-rendering (#description) so the AnalyserOrchestration
  # contract need not.
  Location = Data.define(:path, :line_start, :line_end) do
    def description = "#{path.raw}:#{line_start}-#{line_end}"
  end

  # SmellType is the value type from snoot.allium identifying a Reek
  # smell category (e.g. "IrresponsibleModule") by name. Used to group
  # Smells for ranking and to look up vendored documentation.
  SmellType = Data.define(:name)
end
