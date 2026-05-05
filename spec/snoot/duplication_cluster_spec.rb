# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- variant DuplicationCluster : Finding
RSpec.describe Snoot::DuplicationCluster do
  describe ".from_flay_item" do
    subject(:cluster) { described_class.from_flay_item(item) }

    let(:flay_location_a) { double(file: "lib/a.rb", line: 5) }
    let(:flay_location_b) { double(file: "lib/b.rb", line: 17) }
    let(:item) do
      double(structural_hash: 4242, locations: [flay_location_a, flay_location_b])
    end
    let(:expected_locations) do
      Set[
        Snoot::Location.new(path: Snoot::Path.new(raw: "lib/a.rb"), line_start: 5, line_end: 5),
        Snoot::Location.new(path: Snoot::Path.new(raw: "lib/b.rb"), line_start: 17, line_end: 17)
      ]
    end

    it { is_expected.to be_a(described_class) }

    it "stringifies item.structural_hash into the signature" do
      expect(cluster.signature).to eq("4242")
    end

    it "maps every flay location into a Snoot::Location with line_start = line_end" do
      expect(cluster.locations).to eq(expected_locations)
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
