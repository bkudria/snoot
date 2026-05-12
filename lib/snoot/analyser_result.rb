# frozen_string_literal: true

module Snoot
  # The two outcomes of AnalyserOrchestration#analyse from snoot.allium's
  # "Analyser Result" section. On success, Sources bundles the three
  # finding sets. On the first analyser failure, AnalyserFailure tags
  # the failing analyser and carries its message.

  # AnalyserFailure is the value type from snoot.allium surfaced on
  # outcome = analysis_failed. The `analyser` tag (one of :reek, :flog,
  # :flay) names which of the three analysers failed in canonical
  # order; `message` is the human-readable error detail carried on
  # stderr. Produced by AnalyserOrchestration#analyse on a failed run.
  AnalyserFailure = Data.define(:analyser, :message)

  # Sources is the value type from snoot.allium bundling the three
  # analyser outputs for one Run. Produced by AnalyserOrchestration#analyse
  # on a successful invocation; consumed by AnalyseRun's selection phase.
  Sources = Data.define(:smells, :complexities, :duplications)
end
