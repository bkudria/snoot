# frozen_string_literal: true

module Snoot
  # AnalyserOrchestration is the contract from snoot.allium that the CLI
  # surface demands. An implementation must supply five methods:
  #
  #   vendored_doc(smell_type) -> String?
  #   significant_smells(smells) -> Set<Smell>
  #   significant_complexities(complexities) -> Set<ComplexityHit>
  #   significant_duplications(duplications) -> Set<DuplicationCluster>
  #   analyse(paths) -> Sources | AnalyserFailure
  #
  # Each call is pure within a single CLI invocation (the Determinism
  # invariant in snoot.allium). Outputs may differ across invocations as
  # the source under analysis changes; that is not a violation.
  #
  # The contract is duck-typed: any object responding to the five methods
  # qualifies. There is no abstract base class to inherit from. The test
  # double is Snoot::Spec::FakeOrchestration; the production adapter is
  # Snoot::AnalyserOrchestration::Default. Location rendering for the
  # report is carried by Snoot::Location#description, not this contract.
  module AnalyserOrchestration
  end
end
