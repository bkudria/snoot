# frozen_string_literal: true

require "spec_helper"

# FakeOrchestration is the test double for the AnalyserOrchestration contract.
# Its significance methods are identity-by-default so CLI tests exercising
# outcome routing aren't reshaped by floor policy; #analyse mirrors the real
# adapter's canonical Reek -> Flog -> Flay failure order.
RSpec.describe Snoot::Spec::FakeOrchestration do
  describe "significance identity-by-default" do
    let(:fake) { fake_orchestration }

    it "passes smells through unchanged" do
      smells = Set[build_smell, build_smell(smell_type: build_smell_type(name: "Other"))]
      expect(fake.significant_smells(smells)).to eq(smells)
    end

    it "passes complexities through unchanged" do
      hits = Set[build_complexity_hit(score: BigDecimal("1.0"))]
      expect(fake.significant_complexities(hits)).to eq(hits)
    end

    it "passes duplications through unchanged" do
      clusters = Set[build_duplication_cluster]
      expect(fake.significant_duplications(clusters)).to eq(clusters)
    end
  end

  describe "#analyse" do
    let(:smell) { build_smell }
    let(:complexity) { build_complexity_hit }
    let(:duplication) { build_duplication_cluster }
    let(:configured_fake) do
      fake_orchestration(smells: Set[smell], complexities: Set[complexity], duplications: Set[duplication])
    end

    it "returns a Sources bundling the configured analyser outputs" do
      expected = Snoot::Sources.new(smells: Set[smell], complexities: Set[complexity], duplications: Set[duplication])
      expect(configured_fake.analyse(Set[build_path])).to eq(expected)
    end

    it "returns AnalyserFailure(:reek) when reek_raises is set" do
      fake = fake_orchestration(reek_raises: StandardError.new("reek-boom"))
      expect(fake.analyse(Set[build_path]))
        .to be_a(Snoot::AnalyserFailure).and(have_attributes(analyser: :reek, message: "reek-boom"))
    end

    it "returns AnalyserFailure(:flog) when flog_raises is set" do
      fake = fake_orchestration(flog_raises: StandardError.new("flog-boom"))
      expect(fake.analyse(Set[build_path]).analyser).to eq(:flog)
    end

    it "returns AnalyserFailure(:flay) when flay_raises is set" do
      fake = fake_orchestration(flay_raises: StandardError.new("flay-boom"))
      expect(fake.analyse(Set[build_path]).analyser).to eq(:flay)
    end

    it "honours canonical order: when flog and flay both raise, returns :flog" do
      fake = fake_orchestration(
        flog_raises: StandardError.new("flog-first"),
        flay_raises: StandardError.new("flay-also")
      )
      expect(fake.analyse(Set[build_path]).analyser).to eq(:flog)
    end
  end
end
