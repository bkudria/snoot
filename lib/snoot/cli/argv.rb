module Snoot
  module CLI
    # Argv parses the *invocation form* of `exe/snoot` -- the argv shape
    # itself, distinct from the spec-modeled CLI surface in
    # snoot.allium (which excludes CLI argument parsing internals).
    # `run` returns an integer exit code; IO is injected for testability.
    module Argv
      USAGE = <<~HELP.freeze
        Usage: snoot --version
               snoot --help

        Pipeline invocation (snoot <paths>) is not yet implemented;
        see snoot.allium for the intended surface.
      HELP

      module_function

      def run(argv, stdout: $stdout, stderr: $stderr)
        case argv
        in ["--version"] then stdout.write("snoot #{Snoot::VERSION}\n") && 0
        in ["--help"] then stdout.write(USAGE) && 0
        else stderr.write(USAGE) && 1
        end
      end
    end
  end
end
