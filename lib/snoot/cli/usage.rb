# frozen_string_literal: true

module Snoot
  module CLI
    USAGE = <<~HELP.freeze
      snoot - single-finding reek/flog/flay reporter

      Usage: snoot [--] [paths...]
             snoot --version
             snoot --help

      With no path arguments, snoot scans the current directory. Arguments
      after -- are always paths. --help and --version print and exit 0
      whatever else is given.

      How snoot picks the finding:
        One finding per run; a smell finding lists every instance of its type
        across the scanned files. Fix them, then rerun snoot to see the next one.
        Running reek, flog or flay directly skips these rules and lists a different set.
        Smells outrank duplication, and duplication outranks complexity.
        Within a category the largest wins: most instances, most locations, or highest score.
        Ties break by name, then path, then line.
        #{RenderReport.describe_cutoffs(AnalyserOrchestration::Default.significance_cutoffs)};
        flay's own mass threshold (16) still applies.
        .reek.yml (searched from the current directory upward, then ~) configures reek only.
        .flayignore (current directory; dir/**/*.rb for a directory) excludes files from flay;
        flog scans every file.
        The output names smell types still below the cutoff, so a type shows before it counts.
        A smell report says how to set that detector's options under detectors: in .reek.yml.

      Exit codes:
        0   nothing to report
        1   one finding rendered
        2   analyser failure
        64  usage error (unknown flag or missing path)
        70  internal error (a bug in snoot; details on stderr)

      Output:
        The last stdout line of every run is a status line for scripts:
        snoot-status: <outcome> [key=value...], values never containing spaces.
          snoot-status: finding_rendered category=smell type=FeatureEnvy remaining=4
          snoot-status: finding_rendered category=complexity remaining=0
          snoot-status: nothing_to_report
          snoot-status: analysis_failed analyser=reek
          snoot-status: internal_error error=NoMethodError
        remaining counts the significant findings behind this one.
        Usage errors, --help and --version print no status line.

      Example:
        snoot lib/
    HELP
  end
end
