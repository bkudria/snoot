# frozen_string_literal: true

module Snoot
  # Run is the entity from snoot.allium tracking one analysis pass: the
  # input paths, the outcome (pending, finding_rendered,
  # nothing_to_report, analysis_failed), the selected_finding when one
  # was chosen, and the set of smells gathered during analysis.
  # Encodes the declared transitions and gates selected_finding access
  # behind the :finding_rendered outcome.
  Run = Data.define(:paths, :outcome, :selected_finding, :smells, :failure) do
    alias_method :_raw_selected_finding, :selected_finding
    alias_method :_raw_failure, :failure

    def initialize(paths:, outcome:, selected_finding: nil, smells: Set[], failure: nil)
      super
      validate_finding_rendered_invariant!
      validate_analysis_failed_invariant!
      validate_selected_finding_absence!
      validate_failure_absence!
    end

    def selected_finding
      unless outcome == :finding_rendered
        raise StateError,
              "selected_finding is only available when outcome = :finding_rendered (got #{outcome.inspect})"
      end
      _raw_selected_finding
    end

    def failure
      unless outcome == :analysis_failed
        raise StateError,
              "failure is only available when outcome = :analysis_failed (got #{outcome.inspect})"
      end
      _raw_failure
    end

    def validate_finding_rendered_invariant!
      return unless outcome == :finding_rendered
      return if _raw_selected_finding

      raise StateError, "selected_finding required for :finding_rendered"
    end
    private :validate_finding_rendered_invariant!

    def validate_analysis_failed_invariant!
      return unless outcome == :analysis_failed
      return if _raw_failure

      raise StateError, "failure required for :analysis_failed"
    end
    private :validate_analysis_failed_invariant!

    def validate_selected_finding_absence!
      return if outcome == :finding_rendered
      return unless _raw_selected_finding

      raise StateError, "selected_finding only permitted when outcome = :finding_rendered (got #{outcome.inspect})"
    end
    private :validate_selected_finding_absence!

    def validate_failure_absence!
      return if outcome == :analysis_failed
      return unless _raw_failure

      raise StateError, "failure only permitted when outcome = :analysis_failed (got #{outcome.inspect})"
    end
    private :validate_failure_absence!

    def transition_to(target, selected_finding: nil, failure: nil)
      ensure_transition_allowed!(target)
      case target
      when :finding_rendered then transition_finding_rendered(selected_finding)
      when :analysis_failed then transition_analysis_failed(failure)
      else with(outcome: target, selected_finding: nil, failure: nil)
      end
    end

    def ensure_transition_allowed!(target)
      return if Run::TRANSITIONS.fetch(outcome, []).include?(target)

      raise StateError, "transition #{outcome} -> #{target} is not declared"
    end
    private :ensure_transition_allowed!

    def transition_finding_rendered(selected_finding)
      raise StateError, "selected_finding required for :finding_rendered" unless selected_finding

      with(outcome: :finding_rendered, selected_finding: selected_finding, failure: nil)
    end
    private :transition_finding_rendered

    def transition_analysis_failed(failure)
      raise StateError, "failure required for :analysis_failed" unless failure

      with(outcome: :analysis_failed, selected_finding: nil, failure: failure, smells: Set[])
    end
    private :transition_analysis_failed
  end

  Run::TRANSITIONS = {
    pending: %i[finding_rendered nothing_to_report analysis_failed].freeze
  }.freeze
end
