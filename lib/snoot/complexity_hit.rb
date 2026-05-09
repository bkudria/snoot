# frozen_string_literal: true

require "bigdecimal"

module Snoot
  # ComplexityHit is the Finding entity from snoot.allium representing a
  # single high-complexity method reported by Flog: a Location, the
  # offending method_name, and the BigDecimal score used for ranking.
  ComplexityHit = Data.define(:location, :method_name, :score) do
    include Finding

    def doc
      "High complexity hits indicate a method or class doing too much. " \
        "Consider extracting helpers, simplifying conditionals, or " \
        "splitting the responsibility across smaller units."
    end
  end
end
