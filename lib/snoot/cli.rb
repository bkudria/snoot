module Snoot
  # CLI is the surface from snoot.allium that exposes the gem to an
  # Operator. .for narrows on actor type (only Operator is admitted) and
  # returns a CLI value carrying the operator. Invoking run_invoked(paths)
  # emits a RunInvoked event in the [self, events] shape, matching the
  # [run, events] convention used by AnalyseRun. The spec also demands
  # AnalyserOrchestration; that composition is deferred to a later slice.
  module CLI
    Event = Data.define(:name, :operator, :paths, :run, :finding, :sections)

    CLI = Data.define(:operator) do
      def run_invoked(paths, orchestration:)
        events = [Event.new(name: :run_invoked, operator: operator, paths: paths,
                            run: nil, finding: nil, sections: nil)]
        run, analyse_events = AnalyseRun.invoke(paths, orchestration: orchestration)
        events.concat(analyse_events)
        if run.outcome == :finding_rendered
          report = RenderReport.invoke(run)
          events << Event.new(name: :report_emitted, operator: operator, paths: paths,
                              run: run, finding: report.finding, sections: report.sections)
        end
        [run, events]
      end
    end

    module_function

    def for(actor)
      raise TypeError, "CLI requires an Operator, got #{actor.class}" unless actor.is_a?(Operator)

      CLI.new(operator: actor)
    end
  end
end
