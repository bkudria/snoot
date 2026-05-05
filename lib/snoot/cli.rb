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
    NOTHING_TO_REPORT = "nothing to report\n"

    # CLI is the value returned by CLI.for(operator) -- a thin handle
    # carrying the authenticated Operator and exposing run_invoked as
    # the single entry point into the analyse/render pipeline.
    CLI = Data.define(:operator) do
      def run_invoked(paths, orchestration:, stdout: $stdout, stderr: $stderr)
        events = [Event.new(name: :run_invoked, operator: operator, paths: paths,
                            run: nil, finding: nil, sections: nil)]
        run, analyse_events = AnalyseRun.invoke(paths, orchestration: orchestration)
        events.concat(analyse_events)
        case run.outcome
        when :finding_rendered then emit_report(run, orchestration, paths, events, stdout)
        when :nothing_to_report then stdout.write(NOTHING_TO_REPORT)
        when :analysis_failed then emit_failure(analyse_events, stderr)
        end
        [run, events]
      end

      private

      def emit_report(run, orchestration, paths, events, stdout)
        report = RenderReport.invoke(run, orchestration: orchestration)
        sections = report.sections
        stdout.write(format_report(sections))
        events << Event.new(name: :report_emitted, operator: operator, paths: paths,
                            run: run, finding: report.finding, sections: sections)
      end

      def emit_failure(analyse_events, stderr)
        failure = analyse_events.find { |e| e.name == :analysis_failed }
        stderr.write("analysis failed: #{failure.error.message}\n") if failure
      end

      def format_report(sections)
        "#{sections.values.join("\n\n")}\n"
      end
    end

    module_function

    def for(actor)
      raise TypeError, "CLI requires an Operator, got #{actor.class}" unless actor.is_a?(Operator)

      CLI.new(operator: actor)
    end
  end
end
