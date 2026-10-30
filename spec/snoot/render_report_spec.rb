# frozen_string_literal: true

require "spec_helper"
require "bigdecimal"

RSpec.describe Snoot::RenderReport do
  let(:orch) { fake_orchestration(vendored_docs: { "FeatureEnvy" => "## doc" }) }

  describe "rule-success.RenderReport" do
    let(:fe_smell) { build_smell(smell_type: build_smell_type(name: "FeatureEnvy")) }
    let(:fe_run) { build_run_with_finding(fe_smell) }
    let(:fe_report) do
      capture_report { trigger_render_report(fe_run, smells: Set[fe_smell], orchestration: orch) }
    end
    let(:sibling_smell) do
      build_smell(
        smell_type: build_smell_type(name: "FeatureEnvy"),
        location: build_location(path: build_path(raw: "lib/sibling.rb"), line_start: 7, line_end: 7),
        message: "from kwarg"
      )
    end

    it "emits ReportEmitted for a Smell as { header, remaining, instances, tuning, doc }", :aggregate_failures do
      expect(fe_report.run).to eq(fe_run)
      expect(fe_report.finding).to eq(fe_run.selected_finding)
      expect(fe_report.sections.keys).to eq(%i[header remaining instances tuning doc])
    end

    it "groups instances from the smells: kwarg" do
      report = described_class.invoke(fe_run, smells: Set[fe_smell, sibling_smell], remaining: build_remaining,
                                              orchestration: orch)
      expect(report.sections[:instances]).to include("lib/sibling.rb\n  Line 7: from kwarg")
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
    let(:smells) do
      Set[
        smell_at(file: "lib/a.rb", line: 6, message: "Foo has no descriptive comment"),
        smell_at(file: "lib/a.rb", line: 12, message: "Bar has no descriptive comment"),
        smell_at(file: "lib/b.rb", line: 2, message: "Baz has no descriptive comment"),
        smell_at(file: "lib/c.rb", line: 1, message: "Qux has no descriptive comment")
      ]
    end
    let(:run) do
      Snoot::Run.new(paths: Set[build_path], outcome: :finding_rendered, selected_finding: smells.first)
    end
    let(:report) { described_class.invoke(run, smells: smells, remaining: build_remaining, orchestration: doc_orch) }

    it "renders doc from vendored_doc(smell_type)" do
      expect(report.sections[:doc]).to eq("# Irresponsible Module\n\ndoc body")
    end

    it "renders an Instances section starting with the heading" do
      expect(report.sections[:instances]).to start_with("## Instances\n\n")
    end

    it "groups instances by file with 2-space-indented Line N: <message> entries", :aggregate_failures do
      expect(report.sections[:instances]).to include(
        "lib/a.rb\n  Line 6: Foo has no descriptive comment\n  Line 12: Bar has no descriptive comment"
      )
      expect(report.sections[:instances]).to include("lib/b.rb\n  Line 2: Baz has no descriptive comment")
      expect(report.sections[:instances]).to include("lib/c.rb\n  Line 1: Qux has no descriptive comment")
    end

    it "orders files by descending instance count, alphabetical tie-break", :aggregate_failures do
      instances = report.sections[:instances]
      expect(instances.index("lib/a.rb")).to be < instances.index("lib/b.rb")
      expect(instances.index("lib/b.rb")).to be < instances.index("lib/c.rb")
    end

    it "renders a one-line header naming the smell type with instance and file counts" do
      expect(report.sections[:header]).to eq("Irresponsible module: 4 instances across 3 files")
    end

    it "uses singular nouns in the header for a single instance in a single file" do
      single = Set[smells.first]
      report = described_class.invoke(run, smells: single, remaining: build_remaining, orchestration: doc_orch)
      expect(report.sections[:header]).to eq("Irresponsible module: 1 instance across 1 file")
    end

    def tuning_text(options_pointer)
      <<~TEXT.chomp
        Fix every instance, then rerun snoot. If the detector's settings don't suit this codebase, \
        configure it in .reek.yml#{options_pointer}:

            detectors:
              IrresponsibleModule:
                <option>: <value>
      TEXT
    end

    it "renders a fix-first tuning section with a detectors: block keyed by the smell type" do
      expect(report.sections[:tuning]).to eq(tuning_text(""))
    end

    it "points the tuning section at the doc's options when the doc has a Configuration section" do
      orch = fake_orchestration(vendored_docs: { "IrresponsibleModule" => "# IM\n\n## Configuration\n\nopts" })
      report = described_class.invoke(run, smells: smells, remaining: build_remaining, orchestration: orch)
      expect(report.sections[:tuning]).to eq(tuning_text(" (the reek doc below lists its options)"))
    end

    it "omits finding_context for Smell findings" do
      expect(report.sections).not_to have_key(:finding_context)
    end

    it "filters out smells of other types before rendering instances", :aggregate_failures do
      off_type = smell_at(file: "lib/other.rb", line: 99, message: "off-type", type_name: "OtherSmell")
      report = described_class.invoke(run, smells: Set[*smells, off_type], remaining: build_remaining,
                                           orchestration: doc_orch)
      expect(report.sections[:instances]).to include("lib/a.rb")
      expect(report.sections[:instances]).not_to include("lib/other.rb")
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
    let(:report) do
      described_class.invoke(run, smells: Set[], remaining: build_remaining, orchestration: fake_orchestration)
    end

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

    it "emits exactly the four sections header, remaining, finding_context, doc" do
      expect(report.sections.keys).to eq(%i[header remaining finding_context doc])
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
    let(:report) do
      described_class.invoke(run, smells: Set[], remaining: build_remaining, orchestration: fake_orchestration)
    end

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

    it "emits exactly the four sections header, remaining, finding_context, doc" do
      expect(report.sections.keys).to eq(%i[header remaining finding_context doc])
    end
  end

  describe "remaining section" do
    def partial_cutoffs
      "(cutoffs: smell types have no cutoff; complexity hits need score 12.5+; duplication clusters need 3+ locations)"
    end

    let(:hit) { build_complexity_hit }
    let(:run) { build_run_with_finding(hit) }
    let(:cutoffs_orch) do
      fake_orchestration(
        significance_cutoffs: build_cutoffs(smell_type_instances: 2, complexity_score: BigDecimal("25"))
      )
    end

    def remaining_line(remaining, orchestration: cutoffs_orch)
      described_class.invoke(run, smells: Set[], remaining: remaining, orchestration: orchestration)
                     .sections[:remaining]
    end

    it "counts each category and states the cutoffs on one line" do
      expect(remaining_line(build_remaining(smell_types: 2, duplication_clusters: 3, complexity_hits: 4))).to eq(
        "Also significant: 2 smell types, 3 duplication clusters, 4 complexity hits; " \
        "0 smell types below cutoff (cutoffs: smell types need 2+ instances; complexity hits need score 25+; " \
        "duplication clusters have no cutoff)"
      )
    end

    it "uses singular nouns for counts of one and shows zero counts" do
      expect(remaining_line(build_remaining(smell_types: 1, duplication_clusters: 0, complexity_hits: 1)))
        .to start_with("Also significant: 1 smell type, 0 duplication clusters, 1 complexity hit; ")
    end

    it "names the smell types below the cutoff, comma-separated" do
      types = %w[TooManyStatements UtilityFunction].map { |name| build_smell_type(name: name) }
      expect(remaining_line(build_remaining(below_cutoff_smell_types: types))).to include(
        "complexity hits; 2 smell types below cutoff: TooManyStatements, UtilityFunction (cutoffs: "
      )
    end

    it "uses the singular for one below-cutoff smell type" do
      types = [build_smell_type(name: "TooManyStatements")]
      expect(remaining_line(build_remaining(below_cutoff_smell_types: types)))
        .to include("; 1 smell type below cutoff: TooManyStatements (")
    end

    it "states a cutoff for every category the orchestration gates, and none otherwise" do
      cutoffs = build_cutoffs(complexity_score: BigDecimal("12.5"), duplication_locations: 3)
      expect(remaining_line(build_remaining, orchestration: fake_orchestration(significance_cutoffs: cutoffs)))
        .to end_with(partial_cutoffs)
    end
  end
end
