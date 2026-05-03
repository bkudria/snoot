require "spec_helper"
require "set"
require "stringio"

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
        Snoot::CLI.for(operator).run_invoked(
          paths, orchestration: fake_orchestration, stdout: null_io, stderr: null_io
        )
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
        Snoot::CLI.for(operator).run_invoked(
          paths, orchestration: orch, stdout: null_io, stderr: null_io
        )
      end
      report_event = events.find { |e| e.name == :report_emitted }
      expect(report_event).not_to be_nil
      expect(report_event.finding).to eq(smell)
      expect(report_event.sections.keys).to eq(%i[header finding_context doc framing])
    end
  end

  describe "surface-guarantee.StdoutMutuallyExclusive" do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }
    let(:rendered_smell) do
      build_smell(
        smell_type: build_smell_type(name: "Documented"),
        location: build_location(path: build_path(raw: "lib/x.rb"),
                                 line_start: 10, line_end: 20),
        message: "envies"
      )
    end
    let(:rendered_smell_orch) do
      fake_orchestration(smells: Set[rendered_smell],
                         vendored_docs: { "Documented" => "## doc" })
    end

    it "writes the four-section report to stdout on finding_rendered" do
      Snoot::CLI.for(build_operator).run_invoked(
        Set[build_path],
        orchestration: rendered_smell_orch,
        stdout: stdout,
        stderr: stderr
      )
      expect(stdout.string).to start_with("Documented at lib/x.rb:10-20")
      expect(stdout.string).to include("\n\n## doc\n\n")
      expect(stdout.string).to end_with("\n")
      expect(stderr.string).to eq("")
    end

    it "writes 'nothing to report' to stdout on nothing_to_report" do
      Snoot::CLI.for(build_operator).run_invoked(
        Set[build_path],
        orchestration: fake_orchestration,
        stdout: stdout,
        stderr: stderr
      )
      expect(stdout.string).to eq("nothing to report\n")
      expect(stderr.string).to eq("")
    end

    it "writes 'analysis failed: <msg>' to stderr and leaves stdout empty on analysis_failed" do
      orch = fake_orchestration(reek_raises: StandardError.new("boom"))
      Snoot::CLI.for(build_operator).run_invoked(
        Set[build_path],
        orchestration: orch,
        stdout: stdout,
        stderr: stderr
      )
      expect(stdout.string).to eq("")
      expect(stderr.string).to eq("analysis failed: boom\n")
    end
  end

  describe "surface-guarantee.TerminatesInOneOutcome" do
    it "drives the run to :finding_rendered when a documented smell is found" do
      operator = build_operator
      smell = build_smell(smell_type: build_smell_type(name: "Documented"))
      orch = fake_orchestration(smells: Set[smell],
                                vendored_docs: { "Documented" => "## doc" })
      run, _events = Snoot::CLI.for(operator).run_invoked(
        Set[build_path], orchestration: orch, stdout: null_io, stderr: null_io
      )
      expect(run.outcome).to eq(:finding_rendered)
    end

    it "drives the run to :nothing_to_report when no findings are produced" do
      run, _events = Snoot::CLI.for(build_operator).run_invoked(
        Set[build_path],
        orchestration: fake_orchestration,
        stdout: null_io,
        stderr: null_io
      )
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "drives the run to :analysis_failed when an analyser raises" do
      orch = fake_orchestration(reek_raises: StandardError.new("boom"))
      run, _events = Snoot::CLI.for(build_operator).run_invoked(
        Set[build_path], orchestration: orch, stdout: null_io, stderr: null_io
      )
      expect(run.outcome).to eq(:analysis_failed)
    end
  end
end
