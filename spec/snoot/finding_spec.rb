# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- entity Finding + variants Smell | ComplexityHit | DuplicationCluster
RSpec.describe Snoot::Finding do
  describe "sum-type-variant.Smell" do
    it "exposes smell_type, location, message under a Smell guard", :aggregate_failures do
      smell = build_smell
      expect(smell).to be_a(Snoot::Smell)
      expect(smell.smell_type).to be_a(Snoot::SmellType)
      expect(smell.location).to be_a(Snoot::Location)
      expect(smell.message).to be_a(String)
    end
  end

  describe "sum-type-variant.ComplexityHit" do
    it "exposes location, optional method_name, and Decimal score", :aggregate_failures do
      hit = build_complexity_hit
      expect(hit).to be_a(Snoot::ComplexityHit)
      expect(hit.location).to be_a(Snoot::Location)
      expect(hit.method_name).to(satisfy { |v| v.nil? || v.is_a?(String) })
      expect(hit.score).to(satisfy { |v| v.is_a?(Numeric) })
    end
  end

  describe "sum-type-variant.DuplicationCluster" do
    it "exposes signature and a Set of locations", :aggregate_failures do
      dup = build_duplication_cluster
      expect(dup).to be_a(Snoot::DuplicationCluster)
      expect(dup.signature).to be_a(String)
      expect(dup.locations).to all(be_a(Snoot::Location))
      expect(dup.locations.size).to be >= 1
    end
  end
end
