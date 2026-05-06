# frozen_string_literal: true

module Snoot
  # CLI is the surface from snoot.allium that exposes the gem to an
  # Operator. .for narrows on actor type (only Operator is admitted)
  # and returns a CLI value carrying the operator. run_invoked drives
  # the pipeline: emits RunInvoked, calls AnalyseRun to produce a
  # terminal Run, and dispatches on outcome -- writing the formatted
  # four-section report to stdout (finding_rendered), an
  # acknowledgement to stdout (nothing_to_report), or an error line to
  # stderr (analysis_failed) per the StdoutMutuallyExclusive guarantee.
  # Returns [run, events].
  module CLI
    # Event is the audit record emitted by the CLI surface for each
    # observable step (run_invoked, report_emitted) and forwarded
    # AnalyseRun events. Returned alongside the Run so callers can
    # assert on the sequence.
    Event = Data.define(:name, :operator, :paths, :run, :finding, :sections)
    NOTHING_TO_REPORT = "nothing to report -- no findings above snoot's significance floor\n"
    DEFAULT_PATHS = Set[Snoot::Path.new(raw: ".")].freeze

    # Streams bundles the stdout/stderr pair injected at the CLI
    # surface; nested inside Pipeline so the IO sinks travel together
    # with the analyser orchestration through the dispatch chain.
    Streams = Data.define(:stdout, :stderr) do
      def self.default
        new(stdout: $stdout, stderr: $stderr)
      end
    end

    # Pipeline bundles the analyser orchestration and IO streams that
    # together define a CLI invocation's wiring -- the pair flows
    # through run_invoked, the outcome dispatch, and emit_report.
    Pipeline = Data.define(:orchestration, :streams) do
      def self.default
        new(orchestration: AnalyserOrchestration::Default, streams: Streams.default)
      end
    end

    # CLI is the value returned by CLI.for(operator) -- a thin handle
    # carrying the authenticated Operator and exposing run_invoked as
    # the single entry point into the analyse/render pipeline.
    CLI = Data.define(:operator) do
      def run_invoked(paths, pipeline: Pipeline.default)
        paths = Snoot::CLI.default_paths if paths.empty?
        events = [Event.new(name: :run_invoked, operator:, paths:, run: nil, finding: nil, sections: nil)]
        run, analyse_events = AnalyseRun.invoke(paths, orchestration: pipeline.orchestration)
        events.concat(analyse_events)
        Snoot::CLI.emit_warnings(analyse_events, pipeline.streams.stderr)
        events.concat(events_for_outcome(run, analyse_events, pipeline: pipeline))
        [run, events]
      end

      private

      # :reek:FeatureEnvy -- this is the dispatch layer between the
      # pipeline's IO bundle (streams) and the per-outcome writer; the
      # whole job is to route to the right sink.
      def events_for_outcome(run, _analyse_events, pipeline:)
        streams = pipeline.streams
        case run.outcome
        when :finding_rendered then [emit_report(run, pipeline: pipeline)]
        when :nothing_to_report then Snoot::CLI.emit_nothing_to_report(streams.stdout)
        when :analysis_failed then Snoot::CLI.emit_failure(run, streams.stderr)
        else []
        end
      end

      # :reek:FeatureEnvy -- pipeline is the IO/orchestration bundle the
      # CLI threads into both the renderer and the stdout sink; routing
      # both arms through pipeline is the surface contract.
      def emit_report(run, pipeline:)
        RenderReport.invoke(run, orchestration: pipeline.orchestration) => { sections:, finding: }
        pipeline.streams.stdout.write(Snoot::CLI.format_report(sections))
        Event.new(name: :report_emitted, operator: operator, paths: run.paths,
                  run: run, finding: finding, sections: sections)
      end
    end

    module_function

    def for(actor)
      raise TypeError, "CLI requires an Operator, got #{actor.class}" unless actor.is_a?(Operator)

      CLI.new(operator: actor)
    end

    def emit_nothing_to_report(stdout)
      stdout.write(NOTHING_TO_REPORT)
      []
    end

    def emit_failure(run, stderr)
      stderr.write("analysis failed (#{run.failure.analyser}): #{run.failure.message}\n")
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
  end
end
