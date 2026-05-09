# frozen_string_literal: true

module Snoot
  module CLI
    # Pipeline bundles the analyser orchestration and the stdout/stderr
    # pair that together define a CLI invocation's wiring -- the trio
    # flows through run_invoked, the outcome dispatch, and emit_report.
    Pipeline = Data.define(:orchestration, :stdout, :stderr) do
      def self.default
        new(orchestration: AnalyserOrchestration::Default, stdout: $stdout, stderr: $stderr)
      end
    end
  end
end
