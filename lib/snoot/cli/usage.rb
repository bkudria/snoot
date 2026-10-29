# frozen_string_literal: true

module Snoot
  module CLI
    USAGE = <<~HELP.freeze
      snoot - single-finding reek/flog/flay reporter

      Usage: snoot [paths...]
             snoot --version
             snoot --help

      With no path arguments, snoot scans the current directory.

      How snoot picks the finding:
        One finding per run. Fix it, then rerun snoot to see the next one.
        Smells outrank duplication, and duplication outranks complexity.
        Within a category the largest wins: most instances, most locations, or highest score.
        Ties break by name, then path, then line.
        #{RenderReport.describe_cutoffs(AnalyserOrchestration::Default.significance_cutoffs)};
        flay's own mass threshold (16) still applies.
        .reek.yml (searched from the current directory upward, then ~) configures reek only.

      Exit codes:
        0   nothing to report
        1   one finding rendered
        2   analyser failure
        64  usage error

      Example:
        snoot lib/
    HELP
  end
end
