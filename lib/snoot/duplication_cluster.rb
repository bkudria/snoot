# frozen_string_literal: true

module Snoot
  # DuplicationCluster is the Finding entity from snoot.allium
  # representing a structural-duplication cluster reported by Flay: a
  # signature shared across two or more Locations. Cluster size
  # (locations.size) is the ranking key.
  DuplicationCluster = Data.define(:signature, :locations) do
    include Finding

    def kind = DuplicationCluster
    def size = locations.size

    def doc
      "Structural duplication suggests an extracted abstraction is missing. " \
        "Consider whether the duplicated shape belongs to a single helper, " \
        "module, or value type."
    end
  end
end
