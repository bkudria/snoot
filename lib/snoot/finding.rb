# frozen_string_literal: true

module Snoot
  # Sum-type marker for the three Finding variants declared in `snoot.allium`:
  # Smell, ComplexityHit, and DuplicationCluster. Each variant is its own class
  # under the Snoot namespace; this module exists as a shared anchor.
  module Finding
  end
end
