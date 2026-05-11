# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- variant DuplicationCluster : Finding
RSpec.describe Snoot::DuplicationCluster do
  describe "entity-fields.DuplicationCluster" do
    it "exposes signature and a Set of locations", :aggregate_failures do
      dup = build_duplication_cluster
      expect(dup).to be_a(described_class)
      expect(dup.signature).to be_a(String)
      expect(dup.locations).to all(be_a(Snoot::Location))
      expect(dup.locations.size).to be >= 1
    end
  end

  describe "#size" do
    it "returns the count of locations in the cluster" do
      locations = Set[build_location(line_start: 1), build_location(line_start: 2), build_location(line_start: 3)]
      cluster = build_duplication_cluster(locations: locations)
      expect(cluster.size).to eq(3)
    end
  end
end
