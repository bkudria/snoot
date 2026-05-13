# frozen_string_literal: true

module Snoot
  # The two results of AnalyserOrchestration#analyse: Sources on full
  # success, AnalyserFailure on the first analyser error.

  # `analyser` is one of :reek, :flog, :flay (canonical order) -- which
  # analyser failed; `message` is the error detail surfaced on stderr.
  AnalyserFailure = Data.define(:analyser, :message)

  # The three analyser outputs bundled for one Run; consumed by
  # AnalyseRun's selection phase.
  Sources = Data.define(:smells, :complexities, :duplications)
end
