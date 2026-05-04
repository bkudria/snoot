# frozen_string_literal: true

module Snoot
  module CLI
    # Argv parses the *invocation form* of `exe/snoot` -- the argv shape
    # itself, distinct from the spec-modeled CLI surface in
    # snoot.allium (which excludes CLI argument parsing internals).
    # `run` returns an integer exit code; IO and the orchestration adapter
    # are injected for testability.
    module Argv
      USAGE = <<~HELP
        Usage: snoot [paths...]
               snoot --version
               snoot --help

        With no path arguments, snoot scans Dir["lib/**/*.rb"].
      HELP

      EXIT_CODES = {
        finding_rendered: 1,
        nothing_to_report: 0,
        analysis_failed: 1
      }.freeze

      module_function

      def run(argv, stdout: $stdout, stderr: $stderr,
              orchestration: AnalyserOrchestration::Default.new)
        return write_and_return(stdout, "snoot #{Snoot::VERSION}\n", 0) if argv == ["--version"]
        return write_and_return(stdout, USAGE, 0) if argv == ["--help"]
        return write_and_return(stderr, USAGE, 1) if unknown_flag?(argv)

        run_pipeline(argv, stdout: stdout, stderr: stderr, orchestration: orchestration)
      end

      def write_and_return(io, message, code)
        io.write(message)
        code
      end

      def unknown_flag?(argv)
        argv.any? { |a| a.start_with?("-") }
      end

      def run_pipeline(argv, stdout:, stderr:, orchestration:)
        run, _events = Snoot::CLI.for(Snoot::Operator.new).run_invoked(
          build_paths(argv), orchestration: orchestration, stdout: stdout, stderr: stderr
        )
        EXIT_CODES.fetch(run.outcome)
      end

      def build_paths(argv)
        raws = argv.empty? ? Dir["lib/**/*.rb"] : argv
        raws.each_with_object(Set[]) { |r, set| set << Snoot::Path.new(raw: r) }
      end
    end
  end
end
