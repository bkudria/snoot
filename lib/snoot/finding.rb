# frozen_string_literal: true

module Snoot
  # Sum-type marker for the three Finding variants declared in `snoot.allium`:
  # Smell, ComplexityHit, and DuplicationCluster. Each variant `include`s
  # this module so consumers can rely on the structural sum-type relationship.
  module Finding
  end
end
