# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- variant ComplexityHit : Finding
RSpec.describe Snoot::ComplexityHit do
  describe "entity-fields.ComplexityHit" do
    it "exposes location, optional method_name, and Decimal score", :aggregate_failures do
      hit = build_complexity_hit
      expect(hit).to be_a(described_class)
      expect(hit.location).to be_a(Snoot::Location)
      expect(hit.method_name).to(satisfy { |v| v.nil? || v.is_a?(String) })
      expect(hit.score).to(satisfy { |v| v.is_a?(Numeric) })
    end
  end
end
