# frozen_string_literal: true

module Snoot
  # DuplicationCluster is the Finding entity from snoot.allium
  # representing a structural-duplication cluster reported by Flay: a
  # signature shared across two or more Locations. Cluster size
  # (locations.size) is the ranking key.
  DuplicationCluster = Data.define(:signature, :locations) do
    def size = locations.size
  end
end
