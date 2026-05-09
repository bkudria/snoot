# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

# Spec source: snoot.allium -- rule RenderReport
#   when:    run: Run.outcome becomes finding_rendered
#   requires: run.selected_finding != null
#   ensures: ReportEmitted(run, finding, sections: { header, finding_context, doc })
RSpec.describe Snoot::RenderReport do
  let(:orch) { fake_orchestration(vendored_docs: { "FeatureEnvy" => "## doc" }) }

  describe "rule-success.RenderReport" do
    let(:fe_smell) { build_smell(smell_type: build_smell_type(name: "FeatureEnvy")) }
    let(:fe_run) { build_run_with_finding(fe_smell) }
    let(:fe_report) { capture_report { trigger_render_report(fe_run, orchestration: orch) } }

    it "emits ReportEmitted for a Smell as { doc, instances }", :aggregate_failures do
      expect(fe_report.run).to eq(fe_run)
      expect(fe_report.finding).to eq(fe_run.selected_finding)
      expect(fe_report.sections.keys).to eq(%i[doc instances])
    end
  end

  describe "Smell rendering" do
    def smell_at(file:, line:, message:, type_name: "IrresponsibleModule")
      Snoot::Smell.new(
        smell_type: build_smell_type(name: type_name),
        location: build_location(path: build_path(raw: file), line_start: line, line_end: line),
        message: message
      )
    end

    let(:doc_orch) do
      fake_orchestration(vendored_docs: { "IrresponsibleModule" => "# Irresponsible Module\n\ndoc body" })
    end
    let(:run) do
      selected = smell_at(file: "lib/a.rb", line: 6, message: "Foo has no descriptive comment")
      Snoot::Run.new(
        paths: Set[build_path],
        outcome: :finding_rendered,
        selected_finding: selected,
        smells: Set[
          selected,
          smell_at(file: "lib/a.rb", line: 12, message: "Bar has no descriptive comment"),
          smell_at(file: "lib/b.rb", line: 2, message: "Baz has no descriptive comment"),
          smell_at(file: "lib/c.rb", line: 1, message: "Qux has no descriptive comment"),
          smell_at(file: "lib/d.rb", line: 3, message: "irrelevant", type_name: "OtherSmell")
        ]
      )
    end
    let(:report) { described_class.invoke(run, orchestration: doc_orch) }
    let(:instances) { report.sections[:instances] }

    it "renders doc from vendored_doc(smell_type)" do
      expect(report.sections[:doc]).to eq("# Irresponsible Module\n\ndoc body")
    end

    it "renders an Instances section starting with the heading" do
      expect(instances).to start_with("## Instances\n\n")
    end

    it "groups instances by file with 2-space-indented Line N: <message> entries", :aggregate_failures do
      expect(instances).to include(
        "lib/a.rb\n  Line 6: Foo has no descriptive comment\n  Line 12: Bar has no descriptive comment"
      )
      expect(instances).to include("lib/b.rb\n  Line 2: Baz has no descriptive comment")
      expect(instances).to include("lib/c.rb\n  Line 1: Qux has no descriptive comment")
    end

    it "orders files by descending instance count, alphabetical tie-break", :aggregate_failures do
      a_idx = instances.index("lib/a.rb")
      b_idx = instances.index("lib/b.rb")
      c_idx = instances.index("lib/c.rb")
      expect(a_idx).to be < b_idx
      expect(b_idx).to be < c_idx
    end

    it "excludes smells of other types", :aggregate_failures do
      expect(instances).not_to include("lib/d.rb")
      expect(instances).not_to include("irrelevant")
    end

    it "omits header and finding_context for Smell findings", :aggregate_failures do
      expect(report.sections).not_to have_key(:header)
      expect(report.sections).not_to have_key(:finding_context)
    end
  end

  describe "ComplexityHit rendering" do
    let(:hit) do
      build_complexity_hit(
        location: build_location(path: build_path(raw: "lib/y.rb"), line_start: 5, line_end: 30),
        method_name: "Foo#bar",
        score: BigDecimal("12.5")
      )
    end
    let(:run) { build_run_with_finding(hit) }
    let(:report) { described_class.invoke(run, orchestration: fake_orchestration) }

    it "renders header as method, location, score" do
      expect(report.sections[:header]).to eq("High complexity in Foo#bar at lib/y.rb:5-30 (score: 12.5)")
    end

    it "renders finding_context as location, method, score" do
      expect(report.sections[:finding_context]).to eq("lib/y.rb:5-30\n\nMethod: Foo#bar\nScore: 12.5")
    end

    it "renders doc as the high-complexity prose" do
      expect(report.sections[:doc]).to eq(
        "High complexity hits indicate a method or class doing too much. " \
        "Consider extracting helpers, simplifying conditionals, or " \
        "splitting the responsibility across smaller units."
      )
    end

    it "emits exactly the three sections header, finding_context, doc" do
      expect(report.sections.keys).to eq(%i[header finding_context doc])
    end
  end

  describe "DuplicationCluster rendering" do
    let(:locs) do
      Set[
        build_location(path: build_path(raw: "lib/a.rb"), line_start: 1, line_end: 8),
        build_location(path: build_path(raw: "lib/b.rb"), line_start: 4, line_end: 11)
      ]
    end
    let(:cluster) { build_duplication_cluster(signature: "abc123", locations: locs) }
    let(:run) { build_run_with_finding(cluster) }
    let(:report) { described_class.invoke(run, orchestration: fake_orchestration) }

    it "renders header as location count + signature" do
      expect(report.sections[:header]).to eq("Structural duplication: 2 locations (signature: abc123)")
    end

    it "renders finding_context as enumerated locations", :aggregate_failures do
      expect(report.sections[:finding_context]).to start_with("Locations:\n")
      expect(report.sections[:finding_context]).to include("lib/a.rb:1-8")
      expect(report.sections[:finding_context]).to include("lib/b.rb:4-11")
    end

    it "renders doc as the high-duplication prose" do
      expect(report.sections[:doc]).to eq(
        "Structural duplication suggests an extracted abstraction is missing. " \
        "Consider whether the duplicated shape belongs to a single helper, " \
        "module, or value type."
      )
    end

    it "emits exactly the three sections header, finding_context, doc" do
      expect(report.sections.keys).to eq(%i[header finding_context doc])
    end
  end
end
