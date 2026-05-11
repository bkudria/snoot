# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- variant Smell : Finding
RSpec.describe Snoot::Smell do
  describe "entity-fields.Smell" do
    it "exposes smell_type, location, message", :aggregate_failures do
      smell = build_smell
      expect(smell).to be_a(described_class)
      expect(smell.smell_type).to be_a(Snoot::SmellType)
      expect(smell.location).to be_a(Snoot::Location)
      expect(smell.message).to be_a(String)
    end
  end
end
