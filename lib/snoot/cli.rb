# frozen_string_literal: true

require "snoot/cli/argv"
require "snoot/cli/event"
require "snoot/cli/pipeline"
require "snoot/cli/status_line"
require "snoot/cli/internal_error_report"
require "snoot/cli/usage"

module Snoot
  # The CLI surface. cli.rb owns the surface entry points: argv-shape
  # entry (.run -- UsageErrorExit), in-process entry (.run_invoked), the
  # surface constants (banners, exit codes, the default path set), and
  # the IO emitter helpers (emit_warnings, emit_failure,
  # emit_nothing_to_report, format_report). The event values (RunInvoked,
  # ReportEmitted) live in cli/event.rb; the Pipeline value lives in
  # cli/pipeline.rb; the USAGE banner lives in cli/usage.rb; cli/argv.rb
  # splits argv into options and paths. .run prints a BANNERS entry when
  # any option names one, rejects unknown options and missing paths with
  # exit 64, and otherwise threads the paths through .run_invoked,
  # mapping the terminal outcome to an EXIT_CODES integer. Every run ends
  # stdout with its cli/status_line.rb line; an unexpected error escaping
  # the run is written by cli/internal_error_report.rb and exits 70.
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
    NOTHING_TO_REPORT = "nothing to report -- no findings above snoot's significance floor"
    DEFAULT_PATHS = Set[Snoot::Path.new(raw: ".")].freeze

    EXIT_CODES = { finding_rendered: 1, nothing_to_report: 0, analysis_failed: 2, usage_error: 64,
                   internal_error: 70 }.freeze

    BANNERS = {
      %w[--version] => "snoot #{Snoot::VERSION}\n",
      %w[-h --help] => USAGE
    }.freeze

    module_function

    def emit_nothing_to_report(remaining, pipeline)
      below_cutoff = RenderReport.describe_below_cutoff(remaining.below_cutoff_smell_types)
      cutoffs = RenderReport.describe_cutoffs(pipeline.orchestration.significance_cutoffs)
      pipeline.stdout.write("#{NOTHING_TO_REPORT}; #{below_cutoff} (#{cutoffs})\n")
      []
    end

    def emit_failure(run, stderr)
      failure = run.failure
      stderr.write("analysis failed (#{failure.analyser}): #{failure.message}\n")
      []
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
      parsed = Argv.parse(argv)
      banner = lookup_banner(parsed.options)
      return write_and_return(pipeline.stdout, banner, 0) if banner

      rejection = rejection_message(parsed.options, missing_paths(parsed.paths))
      return usage_error(pipeline, rejection) unless rejection.empty?

      run_pipeline(parsed.paths, pipeline: pipeline)
    rescue StandardError => error
      InternalErrorReport.write(pipeline, error)
      EXIT_CODES.fetch(:internal_error)
    end

    def lookup_banner(options)
      options.each do |option|
        banner = BANNERS.find { |flags, _| flags.include?(option) }&.last
        return banner if banner
      end
      nil
    end

    def rejection_message(unknown_options, missing)
      lines = unknown_options.map { |option| "snoot: unknown option: #{option}\n" }
      lines.concat(missing.map { |raw| "snoot: no such file or directory: #{raw}\n" })
      lines << "Try 'snoot --help' for usage.\n" if unknown_options.any?
      lines.join
    end

    def usage_error(pipeline, message)
      write_and_return(pipeline.stderr, message, EXIT_CODES.fetch(:usage_error))
    end

    def missing_paths(raws)
      raws.reject { |raw| File.exist?(raw) }
    end

    def write_and_return(io, message, code)
      io.write(message)
      code
    end

    def run_pipeline(raws, pipeline:)
      run, _events = run_invoked(build_paths(raws), pipeline: pipeline)
      EXIT_CODES.fetch(run.outcome)
    end

    def build_paths(raws)
      raws.each_with_object(Set[]) { |raw, set| set << Path.new(raw: raw) }
    end

    def run_invoked(paths, pipeline: Pipeline.default)
      paths = DEFAULT_PATHS if paths.empty?
      collect_events(paths, pipeline)
    end

    def collect_events(paths, pipeline)
      AnalyseRun.invoke(paths, orchestration: pipeline.orchestration) =>
        { run:, events: analyse_events, smells:, remaining: }
      emit_warnings(analyse_events, pipeline.stderr)
      events = [RunInvoked.new(paths: paths), *analyse_events,
                *events_for_outcome(run, smells, remaining, pipeline: pipeline)]
      pipeline.stdout.write(StatusLine.for_run(run, remaining))
      [run, events]
    end

    def events_for_outcome(run, smells, remaining, pipeline:)
      case run.outcome
      when :finding_rendered then [emit_report(run, smells, remaining, pipeline: pipeline)]
      when :nothing_to_report then emit_nothing_to_report(remaining, pipeline)
      when :analysis_failed then emit_failure(run, pipeline.stderr)
      else []
      end
    end

    def emit_report(run, smells, remaining, pipeline:)
      RenderReport.invoke(run, smells: smells, remaining: remaining, orchestration: pipeline.orchestration) =>
        { sections:, finding: }
      pipeline.stdout.write(format_report(sections))
      ReportEmitted.new(run: run, finding: finding, sections: sections)
    end
  end
end
