# frozen_string_literal: true

require "bigdecimal"

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

      def build_run(paths: Set[], outcome: :pending, selected_finding: nil, failure: nil)
        Snoot::Run.new(
          paths: paths, outcome: outcome,
          selected_finding: selected_finding, failure: failure
        )
      end

      def build_analyser_failure(analyser: :reek, message: "boom")
        Snoot::AnalyserFailure.new(analyser: analyser, message: message)
      end

      def build_run_at(outcome, with_finding: nil, with_failure: nil)
        case outcome
        when :pending, :nothing_to_report
          build_run(outcome: outcome)
        when :analysis_failed
          build_run(outcome: :analysis_failed, failure: with_failure || build_analyser_failure)
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

      def build_run_with_finding(finding, smells: nil)
        Snoot::Run.new(
          paths: Set[build_path],
          outcome: :finding_rendered,
          selected_finding: finding,
          smells: smells || (finding.is_a?(Snoot::Smell) ? Set[finding] : Set[])
        )
      end

      def build_smell_with_doc
        build_smell(smell_type: build_smell_type(name: "Documented"))
      end

      def fake_orchestration(**)
        Snoot::Spec::FakeOrchestration.new(**)
      end
    end
  end
end
