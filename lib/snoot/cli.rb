# frozen_string_literal: true

require "snoot/cli/event"
require "snoot/cli/pipeline"

module Snoot
  # The CLI surface. cli.rb owns the surface entry points: argv-shape
  # entry (.run -- UsageErrorExit), in-process entry (.run_invoked), the
  # surface constants (banners, exit codes, the default path set), and
  # the IO emitter helpers (emit_warnings, emit_failure,
  # emit_nothing_to_report, format_report). The event values (RunInvoked,
  # ReportEmitted) live in cli/event.rb; the Pipeline value lives in
  # cli/pipeline.rb. .run consults BANNERS for --version/--help, rejects
  # unknown flags with exit 64, and otherwise threads argv through
  # .run_invoked, mapping the terminal outcome to an EXIT_CODES integer.
  #
  # The two entry points return deliberately different shapes. .run is
  # the POSIX boundary: argv -> Integer, consumed by `exit
  # Snoot::CLI.run(ARGV)` in exe/snoot. .run_invoked is the in-process
  # boundary: Set<Path> -> [Run, Array of event values], used by tests
  # and any library embedding that needs the full event list. Internally
  # .run calls .run_invoked and projects Run#outcome through EXIT_CODES,
  # so the integer is a lossy view of the Run; callers that need the Run,
  # the events, or both must use .run_invoked.
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
        next unless event.is_a?(AnalyseRun::SkippedDocLessSmellWarned)

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
      run, _events = run_invoked(build_paths(argv), pipeline: pipeline)
      EXIT_CODES.fetch(run.outcome)
    end

    def build_paths(argv)
      argv.each_with_object(Set[]) { |raw, set| set << Path.new(raw: raw) }
    end

    def run_invoked(paths, pipeline: Pipeline.default)
      paths = default_paths if paths.empty?
      events = [RunInvoked.new(paths: paths)]
      AnalyseRun.invoke(paths, orchestration: pipeline.orchestration) =>
        { run:, events: analyse_events, smells: }
      events.concat(analyse_events)
      emit_warnings(analyse_events, pipeline.stderr)
      events.concat(events_for_outcome(run, smells, pipeline: pipeline))
      [run, events]
    end

    def events_for_outcome(run, smells, pipeline:)
      case run.outcome
      when :finding_rendered then [emit_report(run, smells, pipeline: pipeline)]
      when :nothing_to_report then emit_nothing_to_report(pipeline.stdout)
      when :analysis_failed then emit_failure(run, pipeline.stderr)
      else []
      end
    end

    def emit_report(run, smells, pipeline:)
      RenderReport.invoke(run, smells: smells, orchestration: pipeline.orchestration) =>
        { sections:, finding: }
      pipeline.stdout.write(format_report(sections))
      ReportEmitted.new(run: run, finding: finding, sections: sections)
    end
  end
end
