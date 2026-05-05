# frozen_string_literal: true

require "bigdecimal"

module Snoot
  # ComplexityHit is the Finding entity from snoot.allium representing a
  # single high-complexity method reported by Flog: a Location, the
  # offending method_name, and the BigDecimal score used for ranking.
  ComplexityHit = Data.define(:location, :method_name, :score) do
    include Finding

    def kind = :ComplexityHit
  end
end
