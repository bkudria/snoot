# frozen_string_literal: true

module Snoot
  # Run is the entity from snoot.allium tracking one analysis pass: the
  # input paths, the outcome (pending, finding_rendered,
  # nothing_to_report, analysis_failed), and the selected_finding when
  # one was chosen. Encodes the declared transitions and the two-sided
  # presence invariants on selected_finding and failure.
  Run = Data.define(:paths, :outcome, :selected_finding, :failure) do
    def initialize(paths:, outcome:, selected_finding: nil, failure: nil)
      super
      validate_selected_finding!
      validate_failure!
    end

    def validate_selected_finding!
      if outcome == :finding_rendered
        return if selected_finding

        raise StateError, "selected_finding required for :finding_rendered"
      end
      return unless selected_finding

      raise StateError, "selected_finding only permitted when outcome = :finding_rendered (got #{outcome.inspect})"
    end
    private :validate_selected_finding!

    def validate_failure!
      if outcome == :analysis_failed
        return if failure

        raise StateError, "failure required for :analysis_failed"
      end
      return unless failure

      raise StateError, "failure only permitted when outcome = :analysis_failed (got #{outcome.inspect})"
    end
    private :validate_failure!

    def transition_to(target, selected_finding: nil, failure: nil)
      ensure_transition_allowed!(target)
      with(outcome: target, selected_finding: selected_finding, failure: failure)
    end

    def ensure_transition_allowed!(target)
      return if Run::TRANSITIONS.fetch(outcome, []).include?(target)

      raise StateError, "transition #{outcome} -> #{target} is not declared"
    end
    private :ensure_transition_allowed!
  end

  Run::TRANSITIONS = {
    pending: %i[finding_rendered nothing_to_report analysis_failed].freeze
  }.freeze
end
