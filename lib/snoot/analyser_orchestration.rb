# frozen_string_literal: true

module Snoot
  # The duck-typed orchestration contract the CLI demands -- any object
  # responding to these five methods qualifies (no base class to inherit):
  #
  #   vendored_doc(smell_type) -> String?
  #   significant_smells(smells) -> Set<Smell>
  #   significant_complexities(complexities) -> Set<ComplexityHit>
  #   significant_duplications(duplications) -> Set<DuplicationCluster>
  #   analyse(paths) -> Sources | AnalyserFailure
  #
  # Each call is pure within a single CLI invocation (see snoot.allium's
  # Determinism invariant); outputs may differ across invocations as the
  # source under analysis changes -- not a violation. The test double is
  # Snoot::Spec::FakeOrchestration; the production adapter is
  # Snoot::AnalyserOrchestration::Default. Report location rendering is
  # Snoot::Location#description's job, not this contract's.
  module AnalyserOrchestration
  end
end
