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

      BANNERS = {
        ["--version"] => "snoot #{Snoot::VERSION}\n",
        ["--help"] => USAGE
      }.freeze

      module_function

      def run(argv, pipeline: Snoot::CLI::Pipeline.default)
        streams = pipeline.streams
        banner = BANNERS[argv]
        return write_and_return(streams.stdout, banner, 0) if banner
        return write_and_return(streams.stderr, USAGE, 1) if unknown_flag?(argv)

        run_pipeline(argv, pipeline: pipeline)
      end

      def write_and_return(io, message, code)
        io.write(message)
        code
      end

      def unknown_flag?(argv)
        argv.any? { |arg| arg.start_with?("-") }
      end

      def run_pipeline(argv, pipeline:)
        run, _events = Snoot::CLI.for(Snoot::Operator.new).run_invoked(
          build_paths(argv), pipeline: pipeline
        )
        EXIT_CODES.fetch(run.outcome)
      end

      def build_paths(argv)
        raws = argv.empty? ? Dir["lib/**/*.rb"] : argv
        raws.each_with_object(Set[]) { |raw, set| set << Snoot::Path.new(raw: raw) }
      end
    end
  end
end
