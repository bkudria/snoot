require "spec_helper"
require "set"

# Spec source: snoot.allium -- surface CLI
#   facing operator: Operator
#   provides: RunInvoked(operator, paths)
RSpec.describe "CLI surface" do
  describe "surface-actor.CLI" do
    it "is accessible to an Operator" do
      operator = build_operator
      expect(Snoot::CLI.for(operator)).not_to be_nil
    end

    it "is not accessible to a non-Operator (e.g. ReportConsumer)" do
      consumer = build_report_consumer
      expect { Snoot::CLI.for(consumer) }.to raise_error(StandardError)
    end
  end

  describe "surface-provides.CLI" do
    it "exposes RunInvoked(operator, paths) when invoked by an Operator" do
      operator = build_operator
      paths = Set[Snoot::Path.new(raw: "lib/foo.rb")]
      events = capture_emitted_events do
        Snoot::CLI.for(operator).run_invoked(paths, orchestration: fake_orchestration)
      end
      expect(events).to include(have_attributes(name: :run_invoked, paths: paths))
    end

    it "emits ReportEmitted when the run terminates in finding_rendered" do
      operator = build_operator
      paths = Set[build_path]
      smell = build_smell(smell_type: build_smell_type(name: "Documented"))
      orch = fake_orchestration(smells: Set[smell],
                                vendored_docs: { "Documented" => "## doc" })
      events = capture_emitted_events do
        Snoot::CLI.for(operator).run_invoked(paths, orchestration: orch)
      end
      expect(events).to include(
        have_attributes(name: :report_emitted, finding: smell,
                        sections: %i[header finding_context doc framing])
      )
    end
  end

  describe "surface-guarantee.TerminatesInOneOutcome" do
    it "drives the run to :finding_rendered when a documented smell is found" do
      operator = build_operator
      smell = build_smell(smell_type: build_smell_type(name: "Documented"))
      orch = fake_orchestration(smells: Set[smell],
                                vendored_docs: { "Documented" => "## doc" })
      run, _events = Snoot::CLI.for(operator).run_invoked(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:finding_rendered)
    end

    it "drives the run to :nothing_to_report when no findings are produced" do
      operator = build_operator
      run, _events = Snoot::CLI.for(operator).run_invoked(
        Set[build_path], orchestration: fake_orchestration
      )
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "drives the run to :analysis_failed when an analyser raises" do
      operator = build_operator
      orch = fake_orchestration(reek_raises: StandardError.new("boom"))
      run, _events = Snoot::CLI.for(operator).run_invoked(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:analysis_failed)
    end
  end
end
