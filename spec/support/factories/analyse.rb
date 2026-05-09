# frozen_string_literal: true

module Snoot
  module Spec
    module Factories
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
    end
  end
end
