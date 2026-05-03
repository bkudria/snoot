require "spec_helper"

# Spec source: snoot.allium -- rule RenderReport
#   when:    run: Run.outcome becomes finding_rendered
#   requires: run.selected_finding != null
#   ensures: ReportEmitted(run, finding, sections: { header, finding_context, doc, framing })
RSpec.describe "RenderReport rule" do
  describe "rule-success.RenderReport" do
    it "emits ReportEmitted with the four sections in declared order" do
      skip "bridge: RenderReport not implemented"
      run = build_run_with_finding(build_smell_with_doc)
      report = capture_report { trigger_render_report(run) }
      expect(report.run).to eq(run)
      expect(report.finding).to eq(run.selected_finding)
      expect(report.sections).to eq([:header, :finding_context, :doc, :framing])
    end
  end

  describe "rule-failure.RenderReport.1" do
    it "is rejected when run.selected_finding is nil" do
      skip "bridge: RenderReport not implemented"
      # Note: in a well-formed system the requires clause is guaranteed by the
      # SingleFindingPerRun invariant. This test asserts the guard regardless.
      run = build_run_with_finding(nil)
      expect { trigger_render_report(run) }.to raise_error(/selected_finding/i)
    end
  end

  # Bridge helpers
  def build_run_with_finding(_finding); raise "TODO"; end
  def build_smell_with_doc;             raise "TODO"; end
  def trigger_render_report(_run);      raise "TODO"; end
  def capture_report(&_blk);            raise "TODO"; end
end
