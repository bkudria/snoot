require "spec_helper"
require "set"

# Spec source: snoot.allium -- rule AnalyseRun
#   when:    RunInvoked(paths)
#   ensures: Run.created with outcome in {finding_rendered, nothing_to_report,
#            analysis_failed}; emits SkippedDocLessSmellWarned when the
#            top-overall finding is a Smell whose vendored doc is missing.
RSpec.describe "AnalyseRun rule" do
  describe "rule-success.AnalyseRun" do
    it "creates a Run terminating in one of the three declared outcomes" do
      skip "bridge: AnalyseRun service not implemented"
      paths = Set[Snoot::Path.new(raw: "lib/foo.rb")]
      run = invoke_analyse_run(paths)
      expect(run).to be_a(Snoot::Run)
      expect(run.paths).to eq(paths)
      expect(run.outcome).to be_in([:finding_rendered, :nothing_to_report, :analysis_failed])
    end

    it "filters reek smells without vendored docs out of the candidate pool" do
      skip "bridge: AnalyseRun + vendored_doc lookup not implemented"
      # Spec: documented_smell_findings = filter(smell_findings,
      #   s => vendored_doc(s.smell_type) != null)
      run = invoke_analyse_run_with_only_doc_less_smells
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "emits SkippedDocLessSmellWarned when the top-overall finding is a doc-less smell" do
      skip "bridge: AnalyseRun + warning emission not implemented"
      # Spec: nested if-guards on top_finding_overall narrow to Smell variant
      # before accessing smell_type, then check vendored_doc(smell_type) = null.
      events = capture_emitted_events { invoke_analyse_run_with_doc_less_top_smell }
      expect(events).to include(have_attributes(name: :skipped_doc_less_smell_warned))
    end
  end

  # Bridge helpers
  def invoke_analyse_run(_paths);                  raise "TODO"; end
  def invoke_analyse_run_with_only_doc_less_smells; raise "TODO"; end
  def invoke_analyse_run_with_doc_less_top_smell;   raise "TODO"; end
  def capture_emitted_events(&_blk);                raise "TODO"; end
end
