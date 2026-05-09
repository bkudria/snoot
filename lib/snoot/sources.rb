# frozen_string_literal: true

module Snoot
  # Sources is the value type from snoot.allium bundling the three
  # analyser outputs for one Run. Produced by AnalyserOrchestration#analyse
  # on a successful invocation; consumed by AnalyseRun's selection phase.
  Sources = Data.define(:smells, :complexities, :duplications)
end
