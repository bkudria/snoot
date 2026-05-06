# frozen_string_literal: true

require "bigdecimal"
require "fileutils"
require "stringio"
require "tempfile"
require "tmpdir"

module Snoot
  module Spec
    module Factories # rubocop:disable Metrics/ModuleLength
      def null_io
        StringIO.new
      end

      def with_ruby_tempfile(source)
        Tempfile.create(["snoot_fixture", ".rb"]) do |f|
          f.write(source)
          f.flush
          yield f.path
        end
      end

      def analyse_reek(source, adapter: Snoot::AnalyserOrchestration::Default)
        result = nil
        captured_path = nil
        with_ruby_tempfile(source) do |path|
          captured_path = path
          result = adapter.reek_analyse(Set[Snoot::Path.new(raw: path)])
        end
        [result, captured_path]
      end

      def analyse_flog(source, adapter: Snoot::AnalyserOrchestration::Default)
        result = nil
        captured_path = nil
        with_ruby_tempfile(source) do |path|
          captured_path = path
          result = adapter.flog_analyse(Set[Snoot::Path.new(raw: path)])
        end
        [result, captured_path]
      end

      def analyse_flay(src1, src2, adapter: Snoot::AnalyserOrchestration::Default)
        result = nil
        paths = []
        with_ruby_tempfile(src1) do |p1|
          with_ruby_tempfile(src2) do |p2|
            paths = [p1, p2]
            result = adapter.flay_analyse(Set[Snoot::Path.new(raw: p1), Snoot::Path.new(raw: p2)])
          end
        end
        [result, *paths]
      end

      def with_seeded_lib(filename, source)
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            FileUtils.mkdir_p("lib")
            File.write("lib/#{filename}", source)
            yield
          end
        end
      end

      def with_seeded_cwd(filename, source)
        Dir.mktmpdir do |dir|
          Dir.chdir(dir) do
            File.write(filename, source)
            yield
          end
        end
      end

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

      def trigger_render_report(run, orchestration: fake_orchestration)
        Snoot::RenderReport.invoke(run, orchestration: orchestration)
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
