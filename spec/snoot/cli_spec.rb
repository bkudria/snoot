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
    pipeline = Snoot::CLI::Pipeline.new(orchestration: orchestration, stdout: stdout, stderr: stderr)
    described_class.for(operator).run_invoked(paths, pipeline: pipeline)
  end

  describe "surface-actor.CLI" do
    it "is accessible to an Operator" do
      expect(described_class.for(build_operator)).not_to be_nil
    end

    it "is not accessible to a non-Operator" do
      expect { described_class.for(Object.new) }.to raise_error(StandardError)
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
      expect(stdout.string).to eq("nothing to report -- no findings above snoot's significance floor\n")
      expect(stderr.string).to eq("")
    end

    context "when the top finding is a doc-less smell" do
      let(:smell) { build_smell(smell_type: build_smell_type(name: "Undocumented")) }
      let(:orchestration) { fake_orchestration(smells: Set[smell]) }

      it "writes a missing-vendored-doc warning to stderr (SkippedDocLessSmellWarned)", :aggregate_failures do
        run_cli
        expect(stderr.string).to eq("warning: skipping doc-less smell type 'Undocumented'\n")
        expect(stdout.string).to eq("nothing to report -- no findings above snoot's significance floor\n")
      end
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

  describe "surface-guarantee.EmptyPathsDefault" do
    let(:default_paths) { Set[Snoot::Path.new(raw: ".")] }

    it "normalises an empty path set to {Path('.')} before RunInvoked fires", :aggregate_failures do
      run, events = run_cli(Set[])
      expect(run.paths).to eq(default_paths)
      run_invoked = events.find { |e| e.name == :run_invoked }
      expect(run_invoked.paths).to eq(default_paths)
    end
  end

  describe "surface-guarantee.TerminatesInOneOutcome" do
    subject(:outcome) { run_cli.first.outcome }

    context "with a documented smell" do
      let(:smell) { build_smell(smell_type: build_smell_type(name: "Documented")) }
      let(:orchestration) do
        fake_orchestration(smells: Set[smell], vendored_docs: { "Documented" => "## doc" })
      end

      it { is_expected.to eq(:finding_rendered) }
    end

    it { is_expected.to eq(:nothing_to_report) }

    context "when an analyser raises" do
      let(:orchestration) { fake_orchestration(reek_raises: StandardError.new("boom")) }

      it { is_expected.to eq(:analysis_failed) }
    end
  end

  describe ".run" do
    let(:smelly_ruby) do
      <<~RUBY
        class Dirty
          def smelly_a(x)
            x.a + x.b + x.c + x.d
          end

          def smelly_b(y)
            y.a + y.b + y.c + y.d
          end
        end
      RUBY
    end
    let(:smell_free_ruby) do
      <<~RUBY
        # A trivial, smell-free class for the empty-result test.
        class Tiny
        end
      RUBY
    end

    def run_argv(argv, orchestration: Snoot::AnalyserOrchestration::Default)
      pipeline = Snoot::CLI::Pipeline.new(orchestration: orchestration, stdout: stdout, stderr: stderr)
      described_class.run(argv, pipeline: pipeline)
    end

    it "writes the version to stdout and returns 0 for --version", :aggregate_failures do
      code = run_argv(["--version"])
      expect(code).to eq(0)
      expect(stdout.string).to eq("snoot #{Snoot::VERSION}\n")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stdout and returns 0 for --help", :aggregate_failures do
      code = run_argv(["--help"])
      expect(code).to eq(0)
      expect(stdout.string).to include("Usage: snoot", "[paths...]")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stderr and returns 64 for an unknown flag", :aggregate_failures do
      code = run_argv(["--unknown-flag"])
      expect(code).to eq(64)
      expect(stderr.string).to include("Usage: snoot")
      expect(stdout.string).to be_empty
    end

    it "passes a single Ruby file path through the pipeline (nothing_to_report)", :aggregate_failures do
      with_ruby_tempfile(smell_free_ruby) do |path|
        code = run_argv([path])
        expect(code).to eq(0)
        expect([stdout.string, stderr.string]).to eq([Snoot::CLI::NOTHING_TO_REPORT, ""])
      end
    end

    it "exits 1 with a doc + Instances report on stdout when a Smell finding is rendered", :aggregate_failures do
      with_ruby_tempfile(smelly_ruby) do |path|
        code = run_argv([path])
        expect(code).to eq(1)
        expect(stdout.string).to include("## Instances\n\n", path)
      end
    end

    it "returns an empty path set for empty argv (CLI surface owns @guarantee EmptyPathsDefault)" do
      expect(described_class.build_paths([])).to eq(Set[])
    end

    it "scans the current directory when no paths are given", :aggregate_failures do
      with_seeded_cwd("dirty.rb", smelly_ruby) do
        code = run_argv([])
        expect(code).to eq(1)
        expect(stdout.string).to include("## Instances\n\n")
      end
    end

    it "exits 2 with stderr message when analysis fails", :aggregate_failures do
      orchestration = fake_orchestration(reek_raises: StandardError.new("boom"))
      code = run_argv(["lib/foo.rb"], orchestration: orchestration)
      expect(code).to eq(2)
      expect(stderr.string).to include("analysis failed (reek):", "boom")
      expect(stdout.string).to be_empty
    end

    it "maps :analysis_failed to exit code 2 in EXIT_CODES" do
      expect(described_class::EXIT_CODES.fetch(:analysis_failed)).to eq(2)
    end
  end
end
