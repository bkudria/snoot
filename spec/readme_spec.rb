# frozen_string_literal: true

require "spec_helper"

RSpec.describe "README.md" do # rubocop:disable RSpec/DescribeClass
  let(:readme) { File.read(File.expand_path("../README.md", __dir__)) }

  it "documents how snoot picks a finding" do
    expect(readme).to include("## How snoot picks a finding")
  end

  it "states the cutoffs the default orchestration applies" do
    cutoffs = Snoot::RenderReport.describe_cutoffs(Snoot::AnalyserOrchestration::Default.significance_cutoffs)
    expect(readme).to include(cutoffs)
  end

  it "lists the usage-error exit code" do
    expect(readme).to include("- `64` —")
  end
end
