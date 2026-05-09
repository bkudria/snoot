# frozen_string_literal: true

module Snoot
  module CLI
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
  end
end
