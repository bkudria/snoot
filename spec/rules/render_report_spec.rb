# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

# Spec source: snoot.allium -- rule RenderReport
#   when:    run: Run.outcome becomes finding_rendered
#   requires: run.selected_finding != null
#   ensures: ReportEmitted(run, finding, sections: { header, finding_context, doc, framing })
RSpec.describe "RenderReport rule" do
  let(:orch) { fake_orchestration(vendored_docs: { "FeatureEnvy" => "## doc" }) }

  describe "rule-success.RenderReport" do
    it "emits ReportEmitted for a Smell as { doc, instances }" do
      smell = build_smell(smell_type: build_smell_type(name: "FeatureEnvy"))
      run = build_run_with_finding(smell)
      report = capture_report { trigger_render_report(run, orchestration: orch) }
      expect(report.run).to eq(run)
      expect(report.finding).to eq(run.selected_finding)
      expect(report.sections.keys).to eq(%i[doc instances])
    end
  end

  describe "rule-failure.RenderReport.1" do
    it "is rejected when run.selected_finding is nil" do
      run = build_run_with_finding(nil)
      expect do
        trigger_render_report(run, orchestration: fake_orchestration)
      end.to raise_error(/selected_finding/i)
    end
  end

  describe "Smell rendering" do
    let(:smell_type) { build_smell_type(name: "IrresponsibleModule") }
    let(:other_type) { build_smell_type(name: "OtherSmell") }
    let(:loc_a6) { build_location(path: build_path(raw: "lib/a.rb"), line_start: 6, line_end: 6) }
    let(:loc_a12) { build_location(path: build_path(raw: "lib/a.rb"), line_start: 12, line_end: 12) }
    let(:loc_b2) { build_location(path: build_path(raw: "lib/b.rb"), line_start: 2, line_end: 2) }
    let(:loc_c1) { build_location(path: build_path(raw: "lib/c.rb"), line_start: 1, line_end: 1) }
    let(:loc_d3) { build_location(path: build_path(raw: "lib/d.rb"), line_start: 3, line_end: 3) }
    let(:s_a6) { Snoot::Smell.new(smell_type: smell_type, location: loc_a6, message: "Foo has no descriptive comment") }
    let(:s_a12) { Snoot::Smell.new(smell_type: smell_type, location: loc_a12, message: "Bar has no descriptive comment") }
    let(:s_b2) { Snoot::Smell.new(smell_type: smell_type, location: loc_b2, message: "Baz has no descriptive comment") }
    let(:s_c1) { Snoot::Smell.new(smell_type: smell_type, location: loc_c1, message: "Qux has no descriptive comment") }
    let(:s_other) { Snoot::Smell.new(smell_type: other_type, location: loc_d3, message: "irrelevant") }
    let(:doc_orch) do
      fake_orchestration(vendored_docs: { "IrresponsibleModule" => "# Irresponsible Module\n\ndoc body" })
    end
    let(:run) do
      Snoot::Run.new(
        paths: Set[build_path],
        outcome: :finding_rendered,
        selected_finding: s_a6,
        smells: Set[s_a6, s_a12, s_b2, s_c1, s_other]
      )
    end
    let(:report) { Snoot::RenderReport.invoke(run, orchestration: doc_orch) }

    it "renders doc from vendored_doc(smell_type)" do
      expect(report.sections[:doc]).to eq("# Irresponsible Module\n\ndoc body")
    end

    it "renders an Instances section starting with the heading" do
      expect(report.sections[:instances]).to start_with("## Instances\n\n")
    end

    it "groups instances by file with 2-space-indented Line N: <message> entries" do
      instances = report.sections[:instances]
      expect(instances).to include("lib/a.rb\n  Line 6: Foo has no descriptive comment\n  Line 12: Bar has no descriptive comment")
      expect(instances).to include("lib/b.rb\n  Line 2: Baz has no descriptive comment")
      expect(instances).to include("lib/c.rb\n  Line 1: Qux has no descriptive comment")
    end

    it "orders files by descending instance count, alphabetical tie-break" do
      instances = report.sections[:instances]
      a_idx = instances.index("lib/a.rb")
      b_idx = instances.index("lib/b.rb")
      c_idx = instances.index("lib/c.rb")
      expect(a_idx).to be < b_idx
      expect(b_idx).to be < c_idx
    end

    it "excludes smells of other types" do
      expect(report.sections[:instances]).not_to include("lib/d.rb")
      expect(report.sections[:instances]).not_to include("irrelevant")
    end

    it "omits header, finding_context, and framing for Smell findings" do
      expect(report.sections).not_to have_key(:header)
      expect(report.sections).not_to have_key(:finding_context)
      expect(report.sections).not_to have_key(:framing)
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
    let(:report) { Snoot::RenderReport.invoke(run, orchestration: fake_orchestration) }

    it "renders header as method, location, score" do
      expect(report.sections[:header]).to eq("High complexity in Foo#bar at lib/y.rb:5-30 (score: 12.5)")
    end

    it "renders finding_context as location, method, score" do
      expect(report.sections[:finding_context]).to eq("lib/y.rb:5-30\n\nMethod: Foo#bar\nScore: 12.5")
    end

    it "renders doc as the high-complexity prose constant" do
      expect(report.sections[:doc]).to eq(Snoot::RenderReport::COMPLEXITY_DOC)
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
    let(:report) { Snoot::RenderReport.invoke(run, orchestration: fake_orchestration) }

    it "renders header as location count + signature" do
      expect(report.sections[:header]).to eq("Structural duplication: 2 locations (signature: abc123)")
    end

    it "renders finding_context as enumerated locations" do
      expect(report.sections[:finding_context]).to start_with("Locations:\n")
      expect(report.sections[:finding_context]).to include("lib/a.rb:1-8")
      expect(report.sections[:finding_context]).to include("lib/b.rb:4-11")
    end

    it "renders doc as the high-duplication prose constant" do
      expect(report.sections[:doc]).to eq(Snoot::RenderReport::DUPLICATION_DOC)
    end
  end

  describe "framing section (non-Smell variants only)" do
    it "is the placeholder string for ComplexityHit" do
      hit = build_complexity_hit
      run = build_run_with_finding(hit)
      report = Snoot::RenderReport.invoke(run, orchestration: fake_orchestration)
      expect(report.sections[:framing]).to eq(Snoot::RenderReport::FRAMING_PLACEHOLDER)
    end

    it "is the placeholder string for DuplicationCluster" do
      cluster = build_duplication_cluster
      run = build_run_with_finding(cluster)
      report = Snoot::RenderReport.invoke(run, orchestration: fake_orchestration)
      expect(report.sections[:framing]).to eq(Snoot::RenderReport::FRAMING_PLACEHOLDER)
    end
  end
end
