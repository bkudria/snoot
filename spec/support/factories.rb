require "bigdecimal"
require "set"

module Snoot
  module Spec
    module Factories
      def build_path(raw: "lib/foo.rb")
        Snoot::Path.new(raw: raw)
      end

      def build_location(path: build_path, line_start: 10, line_end: 20)
        Snoot::Location.new(path: path, line_start: line_start, line_end: line_end)
      end

      def build_smell_type(name: "FeatureEnvy")
        Snoot::SmellType.new(name: name)
      end

      def build_smell(smell_type: build_smell_type, location: build_location, message: "method envies another object")
        Snoot::Smell.new(smell_type: smell_type, location: location, message: message)
      end

      def build_complexity_hit(location: build_location, method_name: "Foo#bar", score: BigDecimal("12.5"))
        Snoot::ComplexityHit.new(location: location, method_name: method_name, score: score)
      end

      def build_duplication_cluster(signature: "abc123", locations: Set[build_location])
        Snoot::DuplicationCluster.new(signature: signature, locations: locations)
      end

      def build_run(paths: Set[], outcome: :pending, selected_finding: nil)
        Snoot::Run.new(paths: paths, outcome: outcome, selected_finding: selected_finding)
      end

      def build_run_at(outcome, with_finding: nil)
        case outcome
        when :pending, :nothing_to_report, :analysis_failed
          build_run(outcome: outcome)
        when :finding_rendered
          build_run(outcome: :finding_rendered, selected_finding: with_finding || build_smell)
        else
          raise ArgumentError, "unknown outcome: #{outcome.inspect}"
        end
      end

      def build_report_consumer
        Snoot::ReportConsumer.new
      end

      def build_operator
        Snoot::Operator.new
      end

      def transition!(run, to:)
        run.transition_to(to)
      end

      def fake_orchestration(**)
        Snoot::Spec::FakeOrchestration.new(**)
      end

      def invoke_analyse_run(paths = Set[build_path], orchestration: fake_orchestration)
        run, _events = Snoot::AnalyseRun.invoke(paths, orchestration: orchestration)
        run
      end

      def invoke_analyse_run_with_only_doc_less_smells
        smell = build_smell(smell_type: build_smell_type(name: "Undocumented"))
        invoke_analyse_run(orchestration: fake_orchestration(smells: Set[smell]))
      end

      # Returns [run, events] -- block result for capture_emitted_events.
      def invoke_analyse_run_with_doc_less_top_smell
        smell = build_smell(smell_type: build_smell_type(name: "Undocumented"))
        Snoot::AnalyseRun.invoke(
          Set[build_path],
          orchestration: fake_orchestration(smells: Set[smell])
        )
      end

      def capture_emitted_events
        _run, events = yield
        events
      end

      def build_run_with_finding(finding)
        Snoot::Run.new(
          paths: Set[build_path],
          outcome: :finding_rendered,
          selected_finding: finding
        )
      end

      def build_smell_with_doc
        build_smell(smell_type: build_smell_type(name: "Documented"))
      end

      def trigger_render_report(run)
        Snoot::RenderReport.invoke(run)
      end

      def capture_report
        yield
      end

      def drive_to(target) # rubocop:disable Metrics/MethodLength
        case target
        when :finding_rendered
          smell = build_smell(smell_type: build_smell_type(name: "Documented"))
          invoke_analyse_run(orchestration: fake_orchestration(
            smells: Set[smell], vendored_docs: { "Documented" => "## doc" }
          ))
        when :nothing_to_report
          invoke_analyse_run(orchestration: fake_orchestration)
        when :analysis_failed
          invoke_analyse_run(orchestration: fake_orchestration(
            reek_raises: StandardError.new("boom")
          ))
        else
          raise ArgumentError, "unknown target: #{target.inspect}"
        end
      end
    end
  end
end
