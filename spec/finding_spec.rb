require "spec_helper"

# Spec source: snoot.allium -- entity Finding + variants Smell | ComplexityHit | DuplicationCluster
RSpec.describe "Finding (sum type)" do
  describe "entity-fields.Finding" do
    it "every variant exposes the kind discriminator" do
      skip "bridge: Snoot::Finding family not implemented"
      expect(build_smell.kind).to eq(:Smell)
      expect(build_complexity_hit.kind).to eq(:ComplexityHit)
      expect(build_duplication_cluster.kind).to eq(:DuplicationCluster)
    end
  end

  describe "sum-type-variant.Smell" do
    it "exposes smell_type, location, message under a Smell guard" do
      skip "bridge: Snoot::Smell not implemented"
      smell = build_smell
      expect(smell).to be_a(Snoot::Smell)
      expect(smell.smell_type).to be_a(Snoot::SmellType)
      expect(smell.location).to be_a(Snoot::Location)
      expect(smell.message).to be_a(String)
    end
  end

  describe "sum-type-variant.ComplexityHit" do
    it "exposes location, optional method_name, and Decimal score" do
      skip "bridge: Snoot::ComplexityHit not implemented"
      hit = build_complexity_hit
      expect(hit).to be_a(Snoot::ComplexityHit)
      expect(hit.location).to be_a(Snoot::Location)
      expect(hit.method_name).to satisfy { |v| v.nil? || v.is_a?(String) }
      expect(hit.score).to satisfy { |v| v.is_a?(Numeric) }
    end
  end

  describe "sum-type-variant.DuplicationCluster" do
    it "exposes signature and a Set of locations" do
      skip "bridge: Snoot::DuplicationCluster not implemented"
      dup = build_duplication_cluster
      expect(dup).to be_a(Snoot::DuplicationCluster)
      expect(dup.signature).to be_a(String)
      expect(dup.locations).to all(be_a(Snoot::Location))
      expect(dup.locations.size).to be >= 1
    end
  end

  # Bridge factories -- replace with real builders once lib/snoot exists.
  def build_smell;               raise "TODO: factory for Snoot::Smell"; end
  def build_complexity_hit;      raise "TODO: factory for Snoot::ComplexityHit"; end
  def build_duplication_cluster; raise "TODO: factory for Snoot::DuplicationCluster"; end
end
