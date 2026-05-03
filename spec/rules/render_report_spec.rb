require "spec_helper"
require "bigdecimal"
require "set"

# Spec source: snoot.allium -- rule RenderReport
#   when:    run: Run.outcome becomes finding_rendered
#   requires: run.selected_finding != null
#   ensures: ReportEmitted(run, finding, sections: { header, finding_context, doc, framing })
RSpec.describe "RenderReport rule" do
  let(:orch) { fake_orchestration(vendored_docs: { "FeatureEnvy" => "## doc" }) }

  describe "rule-success.RenderReport" do
    it "emits ReportEmitted with the four sections in declared order" do
      smell = build_smell(smell_type: build_smell_type(name: "FeatureEnvy"))
      run = build_run_with_finding(smell)
      report = capture_report { trigger_render_report(run, orchestration: orch) }
      expect(report.run).to eq(run)
      expect(report.finding).to eq(run.selected_finding)
      expect(report.sections.keys).to eq(%i[header finding_context doc framing])
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
    let(:smell) do
      build_smell(
        smell_type: build_smell_type(name: "FeatureEnvy"),
        location: build_location(path: build_path(raw: "lib/x.rb"), line_start: 10, line_end: 20),
        message: "method envies another object"
      )
    end
    let(:run) { build_run_with_finding(smell) }
    let(:report) { Snoot::RenderReport.invoke(run, orchestration: orch) }

    it "renders header as smell name + location" do
      expect(report.sections[:header]).to eq("FeatureEnvy at lib/x.rb:10-20")
    end

    it "renders finding_context as location and message" do
      expect(report.sections[:finding_context]).to eq("lib/x.rb:10-20\n\nmethod envies another object")
    end

    it "renders doc from vendored_doc(smell_type)" do
      expect(report.sections[:doc]).to eq("## doc")
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

  describe "framing section" do
    it "is the placeholder string regardless of variant" do
      smell = build_smell_with_doc
      run = build_run_with_finding(smell)
      orch_with_doc = fake_orchestration(vendored_docs: { "Documented" => "## d" })
      report = Snoot::RenderReport.invoke(run, orchestration: orch_with_doc)
      expect(report.sections[:framing]).to eq(Snoot::RenderReport::FRAMING_PLACEHOLDER)
    end
  end
end
