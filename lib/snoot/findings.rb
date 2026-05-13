# frozen_string_literal: true

require "bigdecimal"

module Snoot
  # The three Finding variants -- the unit a Run can render. Distinct
  # shapes; AnalyseRun's selection phase ranks within and across them.

  # A single Reek smell instance. Ranked by how often its smell_type
  # recurs within a Run.
  Smell = Data.define(:smell_type, :location, :message)

  # A single high-complexity method reported by Flog; score (BigDecimal)
  # is the ranking key.
  ComplexityHit = Data.define(:location, :method_name, :score)

  # A structural-duplication cluster reported by Flay: a signature
  # shared across two or more Locations. Cluster size (locations.size)
  # is the ranking key.
  DuplicationCluster = Data.define(:signature, :locations) do
    def size = locations.size
  end
end
