# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- rule AnalyseRun
#   when:    RunInvoked(paths)
#   ensures: Run.created with outcome in {finding_rendered, nothing_to_report,
#            analysis_failed}; emits SkippedDocLessSmellWarned when the
#            top-overall finding is a Smell whose vendored doc is missing.
RSpec.describe Snoot::AnalyseRun do
  describe "rule-success.AnalyseRun" do
    it "creates a Run terminating in one of the three declared outcomes", :aggregate_failures do
      paths = Set[Snoot::Path.new(raw: "lib/foo.rb")]
      run = invoke_analyse_run(paths)
      expect(run).to be_a(Snoot::Run)
      expect(run.paths).to eq(paths)
      expect(%i[finding_rendered nothing_to_report analysis_failed]).to include(run.outcome) # rubocop:disable RSpec/ExpectActual
    end

    it "filters reek smells without vendored docs out of the candidate pool" do
      # Spec: documented_smell_findings = filter(smell_findings,
      #   s => vendored_doc(s.smell_type) != null)
      run = invoke_analyse_run_with_only_doc_less_smells
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "emits SkippedDocLessSmellWarned when the top-overall finding is a doc-less smell" do
      # Spec: nested if-guards on top_finding_overall narrow to Smell variant
      # before accessing smell_type, then check vendored_doc(smell_type) = null.
      events = capture_emitted_events { invoke_analyse_run_with_doc_less_top_smell }
      expect(events).to include(have_attributes(name: :skipped_doc_less_smell_warned))
    end
  end

  describe "smells field propagation" do
    let(:documented_smell) { build_smell(smell_type: build_smell_type(name: "Documented")) }
    let(:sibling_smell) do
      build_smell(
        smell_type: build_smell_type(name: "Documented"),
        location: build_location(path: build_path(raw: "lib/y.rb"), line_start: 5, line_end: 5)
      )
    end
    let(:doc_orch) do
      fake_orchestration(
        smells: Set[documented_smell, sibling_smell],
        vendored_docs: { "Documented" => "## doc" }
      )
    end

    it "carries the orchestration's smells onto run.smells when finding_rendered", :aggregate_failures do
      run = invoke_analyse_run(Set[build_path], orchestration: doc_orch)
      expect(run.outcome).to eq(:finding_rendered)
      expect(run.smells).to eq(Set[documented_smell, sibling_smell])
    end

    it "carries the orchestration's smells onto run.smells when nothing_to_report", :aggregate_failures do
      run = invoke_analyse_run(Set[build_path], orchestration: fake_orchestration)
      expect(run.outcome).to eq(:nothing_to_report)
      expect(run.smells).to eq(Set[])
    end
  end

  describe "rule-failure.AnalyseRun -- analyser raises" do
    it "emits an :analysis_failed event carrying the rescued error", :aggregate_failures do
      err = StandardError.new("boom")
      _run, events = described_class.invoke(Set[build_path], orchestration: fake_orchestration(reek_raises: err))
      failure = events.find { |e| e.name == :analysis_failed }
      expect(failure).not_to be_nil
      expect(failure.error).to eq(err)
    end
  end
end
