# frozen_string_literal: true

module Snoot
  # Sum-type marker for the three Finding variants declared in `snoot.allium`:
  # Smell, ComplexityHit, and DuplicationCluster. Variants include this module
  # to pick up `kind`, the discriminator declared on the Finding entity -- it
  # returns the variant's own class.
  module Finding
    def kind = self.class
  end
end
