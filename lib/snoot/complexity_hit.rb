# frozen_string_literal: true

require "bigdecimal"

module Snoot
  ComplexityHit = Data.define(:location, :method_name, :score) do
    include Finding

    def kind = :ComplexityHit
  end
end
