# frozen_string_literal: true

require "spec_helper"
require "stringio"

RSpec.describe Snoot::CLI do
  let(:orchestration) { fake_orchestration }
  let(:stdout) { null_io }
  let(:stderr) { null_io }

  def run_cli(paths = Set[build_path])
    pipeline = Snoot::CLI::Pipeline.new(orchestration: orchestration, stdout: stdout, stderr: stderr)
    described_class.run_invoked(paths, pipeline: pipeline)
  end

  describe "surface-provides.CLI" do
    let(:paths) { Set[Snoot::Path.new(raw: "lib/foo.rb")] }

    it "exposes RunInvoked(paths) when invoked" do
      events = capture_emitted_events { run_cli(paths) }
      expect(events).to include(be_a(Snoot::CLI::RunInvoked).and(have_attributes(paths: paths)))
    end

    context "when a documented smell is rendered" do
      let(:smell) { build_smell(smell_type: build_smell_type(name: "Documented")) }
      let(:orchestration) do
        fake_orchestration(smells: Set[smell], vendored_docs: { "Documented" => "## doc" })
      end

      it "emits ReportEmitted when the run terminates in finding_rendered", :aggregate_failures do
        events = capture_emitted_events { run_cli(paths) }
        report_event = events.find { |e| e.is_a?(Snoot::CLI::ReportEmitted) }
        expect(report_event).not_to be_nil
        expect(report_event.finding).to eq(smell)
        expect(report_event.sections.keys).to eq(%i[header remaining instances tuning doc])
      end
    end
  end

  describe "surface-guarantee.StdoutMutuallyExclusive" do
    def no_cutoffs
      "(cutoffs: smell types have no cutoff; complexity hits have no cutoff; duplication clusters have no cutoff)"
    end

    def nothing_to_report_line
      "nothing to report -- no findings above snoot's significance floor; 0 smell types below cutoff #{no_cutoffs}\n" \
        "snoot-status: nothing_to_report\n"
    end
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

      def documented_tuning
        Snoot::RenderReport::SmellSections.tuning(build_smell_type(name: "Documented"), "## doc")
      end

      def expected_report
        "Documented: 1 instance across 1 file\n\n" \
          "Also significant: 0 smell types, 0 duplication clusters, 0 complexity hits; " \
          "0 smell types below cutoff #{no_cutoffs}\n\n" \
          "## Instances\n\nlib/x.rb\n  Line 10: envies\n\n#{documented_tuning}\n\n## Reference\n\n## doc\n" \
          "snoot-status: finding_rendered category=smell type=Documented remaining=0\n"
      end

      it "writes the header, Instances and doc report to stdout on finding_rendered (Smell)", :aggregate_failures do
        run_cli
        expect(stdout.string).to eq(expected_report)
        expect(stderr.string).to be_empty
      end
    end

    it "writes the enriched 'nothing to report' line to stdout on nothing_to_report", :aggregate_failures do
      run_cli
      expect(stdout.string).to eq(nothing_to_report_line)
      expect(stderr.string).to eq("")
    end

    context "when the top finding is a doc-less smell" do
      let(:smell) { build_smell(smell_type: build_smell_type(name: "Undocumented")) }
      let(:orchestration) { fake_orchestration(smells: Set[smell]) }

      it "writes a missing-vendored-doc warning to stderr (SkippedDocLessSmellWarned)", :aggregate_failures do
        run_cli
        expect(stderr.string).to eq("warning: skipping doc-less smell type 'Undocumented'\n")
        expect(stdout.string).to eq(nothing_to_report_line)
      end
    end

    context "when reek raises" do
      let(:orchestration) { fake_orchestration(reek_raises: StandardError.new("boom")) }

      it "writes 'analysis failed (reek): <msg>' to stderr and only the status line to stdout",
         :aggregate_failures do
        run_cli
        expect(stdout.string).to eq("snoot-status: analysis_failed analyser=reek\n")
        expect(stderr.string).to eq("analysis failed (reek): boom\n")
      end
    end

    context "when flog raises" do
      let(:orchestration) { fake_orchestration(flog_raises: StandardError.new("score-too-high")) }

      it "tags the analyser as flog on stderr and in the status line" do
        run_cli
        expect([stderr.string, stdout.string])
          .to eq(["analysis failed (flog): score-too-high\n", "snoot-status: analysis_failed analyser=flog\n"])
      end
    end

    context "when flay raises" do
      let(:orchestration) { fake_orchestration(flay_raises: StandardError.new("dup-error")) }

      it "tags the analyser as flay on stderr and in the status line" do
        run_cli
        expect([stderr.string, stdout.string])
          .to eq(["analysis failed (flay): dup-error\n", "snoot-status: analysis_failed analyser=flay\n"])
      end
    end
  end

  describe "surface-guarantee.StatusLine" do
    let(:stdout) { StringIO.new }

    def status_line
      run_cli
      stdout.string.lines.last
    end

    def documented_smells(*names)
      names.to_set { |name| build_smell(smell_type: build_smell_type(name:)) }
    end

    def docs_for(*names)
      names.to_h { |name| [name, "## #{name}"] }
    end

    context "with a complexity finding" do
      let(:orchestration) { fake_orchestration(complexities: Set[build_complexity_hit]) }

      it "names the complexity category without a type" do
        expect(status_line).to eq("snoot-status: finding_rendered category=complexity remaining=0\n")
      end
    end

    context "with a duplication finding" do
      let(:orchestration) { fake_orchestration(duplications: Set[build_duplication_cluster]) }

      it "names the duplication category without a type" do
        expect(status_line).to eq("snoot-status: finding_rendered category=duplication remaining=0\n")
      end
    end

    context "with significant findings behind the selected one" do
      let(:orchestration) do
        smells = documented_smells("Alpha", "Bravo", "Charlie")
        fake_orchestration(smells:, vendored_docs: docs_for("Alpha", "Bravo", "Charlie"),
                           complexities: Set[build_complexity_hit], duplications: Set[build_duplication_cluster])
      end

      it "counts every remaining category in remaining" do
        expect(status_line).to eq("snoot-status: finding_rendered category=smell type=Alpha remaining=4\n")
      end
    end
  end

  describe "surface-guarantee.EmptyPathsDefault" do
    let(:default_paths) { Set[Snoot::Path.new(raw: ".")] }

    it "normalises an empty path set to {Path('.')} before RunInvoked fires", :aggregate_failures do
      run, events = run_cli(Set[])
      expect(run.paths).to eq(default_paths)
      run_invoked = events.find { |e| e.is_a?(Snoot::CLI::RunInvoked) }
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

  describe ".emit_warnings" do
    it "ignores events that are not SkippedDocLessSmellWarned" do
      stderr = StringIO.new
      unrelated = Snoot::CLI::RunInvoked.new(paths: Set[])
      described_class.emit_warnings([unrelated], stderr)
      expect(stderr.string).to eq("")
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

    def lonely_ruby
      <<~RUBY
        class Lonely
          def smelly_a(x)
            x.a + x.b + x.c + x.d
          end
        end
      RUBY
    end

    def lonely_below_cutoff
      "3 smell types below cutoff: IrresponsibleModule, UncommunicativeParameterName, UtilityFunction"
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

    it "includes description, exit-code legend, and an example in --help output" do
      run_argv(["--help"])
      expect(stdout.string).to include("reek/flog/flay", "snoot [--] [paths...]", "Exit codes:",
                                       "1   one finding rendered",
                                       "64  usage error (unknown flag or missing path)", "Example:")
    end

    it "explains how snoot picks the finding in --help output" do
      cutoffs = Snoot::RenderReport.describe_cutoffs(Snoot::AnalyserOrchestration::Default.significance_cutoffs)
      run_argv(["--help"])
      expect(stdout.string).to include("How snoot picks the finding:", "rerun snoot", "Smells outrank duplication",
                                       "Ties break by name", cutoffs, ".reek.yml", ".flayignore")
    end

    it "lists the internal-error exit code and the status line in --help output" do
      run_argv(["--help"])
      expect(stdout.string).to include("70  internal error", "Output:", "snoot-status: <outcome>",
                                       "snoot-status: nothing_to_report")
    end

    it "says the output names below-cutoff smell types and where detector settings go in --help" do
      run_argv(["--help"])
      expect(stdout.string).to include("below the cutoff", "under detectors:")
    end

    it "says a smell finding covers every instance and raw analysers list a different set in --help" do
      run_argv(["--help"])
      expect(stdout.string).to include("every instance of its type", "Running reek, flog or flay directly")
    end

    it "writes usage to stdout and returns 0 for -h", :aggregate_failures do
      code = run_argv(["-h"])
      expect(code).to eq(0)
      expect(stdout.string).to include("Usage: snoot", "[paths...]")
      expect(stderr.string).to be_empty
    end

    def run_without_analysis(argv)
      run_argv(argv, orchestration: fake_orchestration(reek_raises: StandardError.new("analysis ran")))
    end

    def try_help
      "Try 'snoot --help' for usage.\n"
    end

    context "with an unknown option" do
      it "exits 64 naming the option, then a --help hint, without analysing" do
        expect([run_without_analysis(["--bogus"]), stdout.string, stderr.string])
          .to eq([64, "", "snoot: unknown option: --bogus\n#{try_help}"])
      end

      it "reports unknown options, then missing paths, then the hint, in one run" do
        run_without_analysis(["nope", "--bogus"])
        expect(stderr.string)
          .to eq("snoot: unknown option: --bogus\nsnoot: no such file or directory: nope\n#{try_help}")
      end

      it "treats a lone '-' as an unknown option" do
        run_without_analysis(["-"])
        expect(stderr.string).to eq("snoot: unknown option: -\n#{try_help}")
      end
    end

    context "with a banner option among other arguments" do
      it "prints help to stdout and exits 0 when --help comes with a path" do
        expect([run_without_analysis(["--help", "nope"]), stdout.string, stderr.string])
          .to eq([0, Snoot::CLI::USAGE, ""])
      end

      it "prints the version to stdout and exits 0 when --version follows a path" do
        expect([run_without_analysis(["nope", "--version"]), stdout.string, stderr.string])
          .to eq([0, "snoot #{Snoot::VERSION}\n", ""])
      end
    end

    it "treats every argument after -- as a path" do
      with_seeded_cwd("-dash.rb", smelly_ruby) do
        expect(run_argv(["--", "-dash.rb"])).to eq(1)
      end
    end

    context "with a path that does not exist" do
      it "exits 64 naming the missing path on stderr, without analysing", :aggregate_failures do
        code = run_without_analysis(["does-not-exist"])
        expect([code, stdout.string]).to eq([64, ""])
        expect(stderr.string).to eq("snoot: no such file or directory: does-not-exist\n")
      end

      it "rejects the whole invocation and names every missing path" do
        with_ruby_tempfile(smell_free_ruby) do |path|
          expect([run_without_analysis([path, "nope-a", "nope-b"]), stderr.string]).to eq(
            [64, "snoot: no such file or directory: nope-a\nsnoot: no such file or directory: nope-b\n"]
          )
        end
      end
    end

    def default_nothing_to_report(below_cutoff = "0 smell types below cutoff")
      "nothing to report -- no findings above snoot's significance floor; #{below_cutoff} " \
        "(cutoffs: smell types need 2+ instances; complexity hits need score 25+; " \
        "duplication clusters have no cutoff)\nsnoot-status: nothing_to_report\n"
    end

    it "passes a single Ruby file path through the pipeline (nothing_to_report)", :aggregate_failures do
      with_ruby_tempfile(smell_free_ruby) do |path|
        code = run_argv([path])
        expect(code).to eq(0)
        expect([stdout.string, stderr.string]).to eq([default_nothing_to_report, ""])
      end
    end

    it "names the smell types below the cutoff when nothing reaches it" do
      with_ruby_tempfile(lonely_ruby) do |path|
        run_argv([path])
        expect(stdout.string).to eq(default_nothing_to_report(lonely_below_cutoff))
      end
    end

    it "exits 1 with a doc + Instances report on stdout when a Smell finding is rendered", :aggregate_failures do
      with_ruby_tempfile(smelly_ruby) do |path|
        code = run_argv([path])
        expect(code).to eq(1)
        expect(stdout.string).to include("Also significant: ", "## Instances\n\n", path)
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
      code = run_argv(["lib"], orchestration: orchestration)
      expect(code).to eq(2)
      expect(stderr.string).to include("analysis failed (reek):", "boom")
      expect(stdout.string).to eq("snoot-status: analysis_failed analyser=reek\n")
    end

    it "maps :analysis_failed to exit code 2 in EXIT_CODES" do
      expect(described_class::EXIT_CODES.fetch(:analysis_failed)).to eq(2)
    end

    context "when the run raises an unexpected error (InternalErrorExit)" do
      def run_raising(error_class)
        smell = build_smell(smell_type: build_smell_type(name: "Documented"))
        docs = Hash.new { |_, name| raise error_class, "no doc lookup for #{name}" }
        run_argv(["lib"], orchestration: fake_orchestration(smells: Set[smell], vendored_docs: docs))
      end

      it "exits 70 naming the error on stderr and in the status line", :aggregate_failures do
        expect(run_raising(NoMethodError)).to eq(70)
        expect(stderr.string).to start_with("snoot: internal error: NoMethodError: no doc lookup for Documented\n")
        expect(stdout.string).to end_with("snoot-status: internal_error error=NoMethodError\n")
      end

      it "writes the backtrace to stderr" do
        run_raising(NoMethodError)
        expect(stderr.string.lines.drop(1)).to include(a_string_matching(/cli_spec\.rb:\d+/))
      end

      it "lets an operator interrupt propagate" do
        expect { run_raising(Interrupt) }.to raise_error(Interrupt)
      end

      def run_on_smelly_source
        Tempfile.create(["smelly", ".rb"]) do |io|
          io.write("class Dirty\n  def smelly(x)\n    x.a + x.b + x.c + x.d\n  end\nend\n")
          io.flush
          run_argv([io.path])
        end
      end

      it "exits 70, not analysis_failed, when snoot fails mapping an analyser's output", :aggregate_failures do
        allow(Snoot::AnalyserOrchestration::ResultMapping)
          .to receive(:smell_from_reek_warning).and_raise(NoMethodError, "mapping bug")
        expect(run_on_smelly_source).to eq(70)
        expect(stdout.string).to end_with("snoot-status: internal_error error=NoMethodError\n")
      end
    end

    it "maps :internal_error to exit code 70 in EXIT_CODES" do
      expect(described_class::EXIT_CODES.fetch(:internal_error)).to eq(70)
    end
  end
end
