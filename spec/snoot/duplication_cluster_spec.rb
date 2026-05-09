# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- variant DuplicationCluster : Finding
RSpec.describe Snoot::DuplicationCluster do
  describe "#size" do
    it "returns the count of locations in the cluster" do
      locations = Set[build_location(line_start: 1), build_location(line_start: 2), build_location(line_start: 3)]
      cluster = build_duplication_cluster(locations: locations)
      expect(cluster.size).to eq(3)
    end
  end
end
