# frozen_string_literal: true

module Snoot
  # AnalyserOrchestration is the contract from snoot.allium that the CLI
  # surface demands. An implementation must supply four methods:
  #
  #   reek_analyse(paths) -> Set<Smell>
  #   flog_analyse(paths) -> Set<ComplexityHit>
  #   flay_analyse(paths) -> Set<DuplicationCluster>
  #   vendored_doc(smell_type) -> String?
  #
  # Each call is pure within a single CLI invocation (the Determinism
  # invariant in snoot.allium). Outputs may differ across invocations as
  # the source under analysis changes; that is not a violation.
  #
  # The contract is duck-typed: any object responding to the four methods
  # qualifies. There is no abstract base class to inherit from. The test
  # double is Snoot::Spec::FakeOrchestration; the production adapter is
  # the Snoot::AnalyserOrchestration::Default module (slice 10A: Reek path
  # + vendored docs; slice 10B: Flog + Flay). Location rendering for the
  # report is carried by Snoot::Location#description, not this contract.
  module AnalyserOrchestration
  end
end
