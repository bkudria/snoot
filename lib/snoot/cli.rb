# frozen_string_literal: true

module Snoot
  # rubocop:disable Metrics/ModuleLength -- the surface bundles argv
  # entry, operator binding, the post-parse pipeline, three Data types,
  # and an Event sub-module; split lengths by responsibility rather
  # than mechanically partitioning the surface.
  # CLI is the surface from snoot.allium that exposes the gem to an
  # Operator. The module covers the full surface: argv-shape entry
  # (.run -- UsageErrorExit), operator binding (.for -> Session), and
  # the post-parse pipeline (run_invoked -- TerminatesInOneOutcome,
  # EmptyPathsDefault, StdoutMutuallyExclusive). .run consults BANNERS
  # for --version/--help, rejects unknown flags with exit 64, and
  # otherwise threads argv through .for(Operator.new).run_invoked,
  # mapping the terminal outcome to an EXIT_CODES integer. .for narrows
  # on actor type (only Operator is admitted) and returns a CLI value
  # carrying the operator. Session#run_invoked emits RunInvoked, calls
  # AnalyseRun to produce a terminal Run, and dispatches on outcome --
  # writing the formatted report to stdout (finding_rendered), an
  # acknowledgement to stdout (nothing_to_report), or an error line to
  # stderr (analysis_failed). Returns [run, events] from run_invoked.
  module CLI
    # Event is the marker module sum-typing the two audit records the
    # CLI surface emits: RunInvoked at the entry point and
    # ReportEmitted on a finding_rendered outcome. AnalyseRun's events
    # are forwarded into the same returned list but live under a
    # parallel marker (Snoot::AnalyseRun::Event).
    module Event
    end

    # RunInvoked carries the Operator and the (possibly defaulted) path
    # set at the moment the surface is entered.
    RunInvoked = Data.define(:operator, :paths) do
      include Event

      def name = :run_invoked
    end

    # ReportEmitted carries the terminal Run, the selected Finding, and
    # the rendered sections produced by RenderReport.
    ReportEmitted = Data.define(:operator, :paths, :run, :finding, :sections) do
      include Event

      def name = :report_emitted
    end
    NOTHING_TO_REPORT = "nothing to report -- no findings above snoot's significance floor\n"
    DEFAULT_PATHS = Set[Snoot::Path.new(raw: ".")].freeze

    USAGE = <<~HELP
      Usage: snoot [paths...]
             snoot --version
             snoot --help

      With no path arguments, snoot scans the current directory.
    HELP

    EXIT_CODES = {
      finding_rendered: 1,
      nothing_to_report: 0,
      analysis_failed: 2
    }.freeze

    USAGE_ERROR_EXIT_CODE = 64

    BANNERS = {
      ["--version"] => "snoot #{Snoot::VERSION}\n",
      ["--help"] => USAGE
    }.freeze

    # Pipeline bundles the analyser orchestration and the stdout/stderr
    # pair that together define a CLI invocation's wiring -- the trio
    # flows through run_invoked, the outcome dispatch, and emit_report.
    Pipeline = Data.define(:orchestration, :stdout, :stderr) do
      def self.default
        new(orchestration: AnalyserOrchestration::Default, stdout: $stdout, stderr: $stderr)
      end
    end

    # Session is the value returned by CLI.for(operator) -- a thin handle
    # carrying the authenticated Operator and exposing run_invoked as
    # the single entry point into the analyse/render pipeline.
    Session = Data.define(:operator) do
      def run_invoked(paths, pipeline: Pipeline.default)
        paths = CLI.default_paths if paths.empty?
        events = [RunInvoked.new(operator:, paths:)]
        run, analyse_events, smells = AnalyseRun.invoke(paths, orchestration: pipeline.orchestration)
        events.concat(analyse_events)
        CLI.emit_warnings(analyse_events, pipeline.stderr)
        events.concat(events_for_outcome(run, smells, pipeline: pipeline))
        [run, events]
      end

      private

      # :reek:FeatureEnvy -- this is the dispatch layer between the
      # pipeline's IO sinks and the per-outcome writer; the whole job
      # is to route to the right sink.
      def events_for_outcome(run, smells, pipeline:)
        case run.outcome
        when :finding_rendered then [emit_report(run, smells, pipeline: pipeline)]
        when :nothing_to_report then CLI.emit_nothing_to_report(pipeline.stdout)
        when :analysis_failed then CLI.emit_failure(run, pipeline.stderr)
        else []
        end
      end

      # :reek:FeatureEnvy -- pipeline is the IO/orchestration bundle the
      # CLI threads into both the renderer and the stdout sink; routing
      # both arms through pipeline is the surface contract.
      def emit_report(run, smells, pipeline:)
        RenderReport.invoke(run, smells: smells, orchestration: pipeline.orchestration) => { sections:, finding: }
        pipeline.stdout.write(CLI.format_report(sections))
        ReportEmitted.new(operator: operator, paths: run.paths,
                          run: run, finding: finding, sections: sections)
      end
    end

    module_function

    def for(actor)
      raise TypeError, "CLI requires an Operator, got #{actor.class}" unless actor.is_a?(Operator)

      Session.new(operator: actor)
    end

    def emit_nothing_to_report(stdout)
      stdout.write(NOTHING_TO_REPORT)
      []
    end

    def emit_failure(run, stderr)
      failure = run.failure
      stderr.write("analysis failed (#{failure.analyser}): #{failure.message}\n")
      []
    end

    def default_paths
      DEFAULT_PATHS
    end

    def emit_warnings(analyse_events, stderr)
      analyse_events.each do |event|
        next unless event.name == :skipped_doc_less_smell_warned

        stderr.write("warning: skipping doc-less smell type '#{event.smell_type.name}'\n")
      end
    end

    def format_report(sections)
      "#{sections.values.join("\n\n")}\n"
    end

    def run(argv, pipeline: Pipeline.default)
      banner = BANNERS[argv]
      return write_and_return(pipeline.stdout, banner, 0) if banner
      return write_and_return(pipeline.stderr, USAGE, USAGE_ERROR_EXIT_CODE) if unknown_flag?(argv)

      run_pipeline(argv, pipeline: pipeline)
    end

    def write_and_return(io, message, code)
      io.write(message)
      code
    end

    def unknown_flag?(argv)
      argv.any? { |arg| arg.start_with?("-") }
    end

    def run_pipeline(argv, pipeline:)
      run, _events = self.for(Operator.new).run_invoked(build_paths(argv), pipeline: pipeline)
      EXIT_CODES.fetch(run.outcome)
    end

    def build_paths(argv)
      argv.each_with_object(Set[]) { |raw, set| set << Path.new(raw: raw) }
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
