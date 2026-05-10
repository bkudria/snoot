# frozen_string_literal: true

module Snoot
  module Spec
    module Factories
      def transition!(run, to:)
        run.transition_to(to)
      end

      def invoke_analyse_run(paths = Set[build_path], orchestration: fake_orchestration)
        Snoot::AnalyseRun.invoke(paths, orchestration: orchestration).run
      end

      def invoke_analyse_run_with_only_doc_less_smells
        smell = build_smell(smell_type: build_smell_type(name: "Undocumented"))
        invoke_analyse_run(orchestration: fake_orchestration(smells: Set[smell]))
      end

      # Returns [run, events] -- block result for capture_emitted_events.
      def invoke_analyse_run_with_doc_less_top_smell
        smell = build_smell(smell_type: build_smell_type(name: "Undocumented"))
        result = Snoot::AnalyseRun.invoke(
          Set[build_path],
          orchestration: fake_orchestration(smells: Set[smell])
        )
        [result.run, result.events]
      end

      def capture_emitted_events
        _run, events = yield
        events
      end

      def trigger_render_report(run, matching_smells: Set[], orchestration: fake_orchestration)
        Snoot::RenderReport.invoke(run, matching_smells: matching_smells, orchestration: orchestration)
      end

      def capture_report
        yield
      end

      def drive_to(target)
        case target
        when :finding_rendered then drive_to_finding_rendered
        when :nothing_to_report then invoke_analyse_run(orchestration: fake_orchestration)
        when :analysis_failed then drive_to_analysis_failed
        else raise ArgumentError, "unknown target: #{target.inspect}"
        end
      end

      def drive_to_finding_rendered
        smell = build_smell(smell_type: build_smell_type(name: "Documented"))
        orch = fake_orchestration(smells: Set[smell], vendored_docs: { "Documented" => "## doc" })
        invoke_analyse_run(orchestration: orch)
      end

      def drive_to_analysis_failed
        invoke_analyse_run(orchestration: fake_orchestration(reek_raises: StandardError.new("boom")))
      end
    end
  end
end
