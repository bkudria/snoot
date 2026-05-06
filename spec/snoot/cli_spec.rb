# frozen_string_literal: true

require "spec_helper"
require "stringio"

# Spec source: snoot.allium -- surface CLI
#   facing operator: Operator
#   provides: RunInvoked(operator, paths)
RSpec.describe Snoot::CLI do
  let(:orchestration) { fake_orchestration }
  let(:stdout) { null_io }
  let(:stderr) { null_io }

  def run_cli(paths = Set[build_path], operator: build_operator)
    streams = Snoot::CLI::Streams.new(stdout: stdout, stderr: stderr)
    pipeline = Snoot::CLI::Pipeline.new(orchestration: orchestration, streams: streams)
    described_class.for(operator).run_invoked(paths, pipeline: pipeline)
  end

  describe "surface-actor.CLI" do
    it "is accessible to an Operator" do
      expect(described_class.for(build_operator)).not_to be_nil
    end

    it "is not accessible to a non-Operator (e.g. ReportConsumer)" do
      expect { described_class.for(build_report_consumer) }.to raise_error(StandardError)
    end
  end

  describe "surface-provides.CLI" do
    let(:paths) { Set[Snoot::Path.new(raw: "lib/foo.rb")] }

    it "exposes RunInvoked(operator, paths) when invoked by an Operator" do
      events = capture_emitted_events { run_cli(paths) }
      expect(events).to include(have_attributes(name: :run_invoked, paths: paths))
    end

    context "when a documented smell is rendered" do
      let(:smell) { build_smell(smell_type: build_smell_type(name: "Documented")) }
      let(:orchestration) do
        fake_orchestration(smells: Set[smell], vendored_docs: { "Documented" => "## doc" })
      end

      it "emits ReportEmitted when the run terminates in finding_rendered", :aggregate_failures do
        events = capture_emitted_events { run_cli(paths) }
        report_event = events.find { |e| e.name == :report_emitted }
        expect(report_event).not_to be_nil
        expect(report_event.finding).to eq(smell)
        expect(report_event.sections.keys).to eq(%i[doc instances])
      end
    end
  end

  describe "surface-guarantee.StdoutMutuallyExclusive" do
    let(:stdout) { StringIO.new }
    let(:stderr) { StringIO.new }

    context "with a documented smell" do
      let(:rendered_smell) do
        build_smell(
          smell_type: build_smell_type(name: "Documented"),
          location: build_location(path: build_path(raw: "lib/x.rb"), line_start: 10, line_end: 20),
          message: "envies"
        )
      end
      let(:orchestration) do
        fake_orchestration(smells: Set[rendered_smell], vendored_docs: { "Documented" => "## doc" })
      end

      it "writes the doc + Instances report to stdout on finding_rendered (Smell)", :aggregate_failures do
        run_cli
        expect(stdout.string).to start_with("## doc\n\n").and(end_with("\n"))
        expect(stdout.string).to include("## Instances\n\n", "lib/x.rb\n  Line 10: envies")
        expect(stderr.string).to be_empty
      end
    end

    it "writes the enriched 'nothing to report' line to stdout on nothing_to_report", :aggregate_failures do
      run_cli
      expect(stdout.string).to eq("nothing to report — no findings above snoot's significance floor\n")
      expect(stderr.string).to eq("")
    end

    context "when reek raises" do
      let(:orchestration) { fake_orchestration(reek_raises: StandardError.new("boom")) }

      it "writes 'analysis failed (reek): <msg>' to stderr and leaves stdout empty", :aggregate_failures do
        run_cli
        expect(stdout.string).to eq("")
        expect(stderr.string).to eq("analysis failed (reek): boom\n")
      end
    end

    context "when flog raises" do
      let(:orchestration) { fake_orchestration(flog_raises: StandardError.new("score-too-high")) }

      it "tags the analyser as flog on stderr" do
        run_cli
        expect(stderr.string).to eq("analysis failed (flog): score-too-high\n")
      end
    end

    context "when flay raises" do
      let(:orchestration) { fake_orchestration(flay_raises: StandardError.new("dup-error")) }

      it "tags the analyser as flay on stderr" do
        run_cli
        expect(stderr.string).to eq("analysis failed (flay): dup-error\n")
      end
    end
  end

  describe "surface-guarantee.TerminatesInOneOutcome" do
    context "with a documented smell" do
      let(:smell) { build_smell(smell_type: build_smell_type(name: "Documented")) }
      let(:orchestration) do
        fake_orchestration(smells: Set[smell], vendored_docs: { "Documented" => "## doc" })
      end

      it "drives the run to :finding_rendered when a documented smell is found" do
        run, _events = run_cli
        expect(run.outcome).to eq(:finding_rendered)
      end
    end

    it "drives the run to :nothing_to_report when no findings are produced" do
      run, _events = run_cli
      expect(run.outcome).to eq(:nothing_to_report)
    end

    context "when an analyser raises" do
      let(:orchestration) { fake_orchestration(reek_raises: StandardError.new("boom")) }

      it "drives the run to :analysis_failed when an analyser raises" do
        run, _events = run_cli
        expect(run.outcome).to eq(:analysis_failed)
      end
    end
  end
end
