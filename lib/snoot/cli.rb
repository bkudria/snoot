# frozen_string_literal: true

require "snoot/cli/event"
require "snoot/cli/pipeline"
require "snoot/cli/session"

module Snoot
  # CLI is the surface from snoot.allium that exposes the gem to an
  # Operator. cli.rb owns the surface entry points: argv-shape entry
  # (.run -- UsageErrorExit), operator binding (.for -> Session), the
  # surface constants (banners, exit codes, the default path set), and
  # the IO emitter helpers (emit_warnings, emit_failure,
  # emit_nothing_to_report, format_report). The Event marker and its
  # variants live in cli/event.rb; the Pipeline value lives in
  # cli/pipeline.rb; the Session value lives in cli/session.rb. .run
  # consults BANNERS for --version/--help, rejects unknown flags with
  # exit 64, and otherwise threads argv through
  # .for(Operator.new).run_invoked, mapping the terminal outcome to an
  # EXIT_CODES integer. .for narrows on actor type (only Operator is
  # admitted) and returns a Session carrying the operator.
  module CLI
    NOTHING_TO_REPORT = "nothing to report -- no findings above snoot's significance floor\n"
    DEFAULT_PATHS = Set[Snoot::Path.new(raw: ".")].freeze

    USAGE = <<~HELP
      Usage: snoot [paths...]
             snoot --version
             snoot --help

      With no path arguments, snoot scans the current directory.
    HELP

    EXIT_CODES = {
      finding_rendered: 1,
      nothing_to_report: 0,
      analysis_failed: 2
    }.freeze

    USAGE_ERROR_EXIT_CODE = 64

    BANNERS = {
      ["--version"] => "snoot #{Snoot::VERSION}\n",
      ["--help"] => USAGE
    }.freeze

    module_function

    def for(actor)
      raise TypeError, "CLI requires an Operator, got #{actor.class}" unless actor.is_a?(Operator)

      Session.new(operator: actor)
    end

    def emit_nothing_to_report(stdout)
      stdout.write(NOTHING_TO_REPORT)
      []
    end

    def emit_failure(run, stderr)
      failure = run.failure
      stderr.write("analysis failed (#{failure.analyser}): #{failure.message}\n")
      []
    end

    def default_paths
      DEFAULT_PATHS
    end

    def emit_warnings(analyse_events, stderr)
      analyse_events.each do |event|
        next unless event.name == :skipped_doc_less_smell_warned

        stderr.write("warning: skipping doc-less smell type '#{event.smell_type.name}'\n")
      end
    end

    def format_report(sections)
      "#{sections.values.join("\n\n")}\n"
    end

    def run(argv, pipeline: Pipeline.default)
      banner = BANNERS[argv]
      return write_and_return(pipeline.stdout, banner, 0) if banner
      return write_and_return(pipeline.stderr, USAGE, USAGE_ERROR_EXIT_CODE) if unknown_flag?(argv)

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
      run, _events = self.for(Operator.new).run_invoked(build_paths(argv), pipeline: pipeline)
      EXIT_CODES.fetch(run.outcome)
    end

    def build_paths(argv)
      argv.each_with_object(Set[]) { |raw, set| set << Path.new(raw: raw) }
    end
  end
end
