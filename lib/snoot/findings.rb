# frozen_string_literal: true

require "bigdecimal"

module Snoot
  # The three Finding variants from snoot.allium's "Entities and
  # Variants" section: the unit a Run can render. Each variant is a
  # distinct shape; AnalyseRun's selection phase ranks within and
  # across them.

  # Smell is the Finding entity from snoot.allium representing a single
  # Reek smell instance: its SmellType, the Location where it was
  # raised, and the Reek-supplied message. Smells are ranked by
  # frequency of their smell_type within a Run.
  Smell = Data.define(:smell_type, :location, :message)

  # ComplexityHit is the Finding entity from snoot.allium representing a
  # single high-complexity method reported by Flog: a Location, the
  # offending method_name, and the BigDecimal score used for ranking.
  ComplexityHit = Data.define(:location, :method_name, :score)

  # DuplicationCluster is the Finding entity from snoot.allium
  # representing a structural-duplication cluster reported by Flay: a
  # signature shared across two or more Locations. Cluster size
  # (locations.size) is the ranking key.
  DuplicationCluster = Data.define(:signature, :locations) do
    def size = locations.size
  end
end
