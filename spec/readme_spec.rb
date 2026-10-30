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

  it "says a smell finding covers every instance and raw analysers list a different set" do
    expect(readme).to include("every instance of its type", "Running reek, flog or flay directly")
  end

  it "says the report names below-cutoff smell types and where detector settings go" do
    expect(readme).to include("below the cutoff", "under `detectors:`")
  end

  it "says flay honours .flayignore, with flay's directory pattern, and flog excludes nothing" do
    expect(readme).to include("`.flayignore`", "`dir/**/*.rb`", "flog has no way to exclude files")
  end

  it "shows -- ending options before a dash-named path" do
    expect(readme).to include("snoot -- -odd-name.rb")
  end

  it "lists the usage-error exit code" do
    expect(readme).to include("- `64` — usage error (unknown flag or missing path")
  end

  it "lists the internal-error exit code" do
    expect(readme).to include("- `70` — internal error")
  end

  it "documents the status line for scripts" do
    expect(readme).to include("## Output for scripts", "snoot-status: finding_rendered category=smell",
                              "snoot-status: internal_error error=")
  end

  it "says every report's doc opens with a ## Reference heading an agent can cut at" do
    expect(readme).to include("opens with a `## Reference` heading")
  end

  it "tells a gate which exit codes mean snoot could not judge the code" do
    expect(readme).to include("`2`, `64` and `70` mean snoot could not judge the code")
  end
end
