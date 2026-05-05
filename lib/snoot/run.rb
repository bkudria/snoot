# frozen_string_literal: true

module Snoot
  # Run is the entity from snoot.allium tracking one analysis pass: the
  # input paths, the outcome (pending, finding_rendered,
  # nothing_to_report, analysis_failed), the selected_finding when one
  # was chosen, and the set of smells gathered during analysis.
  # Encodes the declared transitions and gates selected_finding access
  # behind the :finding_rendered outcome.
  Run = Data.define(:paths, :outcome, :selected_finding, :smells) do
    # rubocop:disable Lint/ConstantDefinitionInBlock
    # The Data.define block IS the class body; this constant is attached to Run.
    TRANSITIONS = {
      pending: %i[finding_rendered nothing_to_report analysis_failed].freeze
    }.freeze
    # rubocop:enable Lint/ConstantDefinitionInBlock

    alias_method :_raw_selected_finding, :selected_finding

    def initialize(paths:, outcome:, selected_finding: nil, smells: Set[])
      super
    end

    def selected_finding
      unless outcome == :finding_rendered
        raise StateError,
              "selected_finding is only available when outcome = :finding_rendered (got #{outcome.inspect})"
      end
      _raw_selected_finding
    end

    def transition_to(target, selected_finding: nil)
      allowed = TRANSITIONS.fetch(outcome, [])
      raise StateError, "transition #{outcome} -> #{target} is not declared" unless allowed.include?(target)

      if target == :finding_rendered
        raise StateError, "selected_finding required for :finding_rendered" unless selected_finding

        with(outcome: target, selected_finding: selected_finding)
      else
        with(outcome: target, selected_finding: nil)
      end
    end
  end
end
