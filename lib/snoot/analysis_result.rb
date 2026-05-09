# frozen_string_literal: true

module Snoot
  # Sum-type marker for the two AnalysisResult variants declared in
  # `snoot.allium`: Sources and AnalyserFailure. Each variant `include`s
  # this module so consumers can rely on the structural sum-type
  # relationship.
  module AnalysisResult
  end
end
