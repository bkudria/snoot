# frozen_string_literal: true

module Snoot
  # Run is the entity from snoot.allium tracking one analysis pass: the
  # input paths, the outcome (pending, finding_rendered,
  # nothing_to_report, analysis_failed), and the selected_finding when
  # one was chosen. Encodes the declared transitions and gates
  # selected_finding access behind the :finding_rendered outcome.
  Run = Data.define(:paths, :outcome, :selected_finding, :failure) do
    alias_method :_raw_selected_finding, :selected_finding
    alias_method :_raw_failure, :failure

    def initialize(paths:, outcome:, selected_finding: nil, failure: nil)
      super
      validate_selected_finding!
      validate_failure!
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

    def validate_selected_finding!
      if outcome == :finding_rendered
        return if _raw_selected_finding

        raise StateError, "selected_finding required for :finding_rendered"
      end
      return unless _raw_selected_finding

      raise StateError, "selected_finding only permitted when outcome = :finding_rendered (got #{outcome.inspect})"
    end
    private :validate_selected_finding!

    def validate_failure!
      if outcome == :analysis_failed
        return if _raw_failure

        raise StateError, "failure required for :analysis_failed"
      end
      return unless _raw_failure

      raise StateError, "failure only permitted when outcome = :analysis_failed (got #{outcome.inspect})"
    end
    private :validate_failure!

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
      with(outcome: :finding_rendered, selected_finding: selected_finding, failure: nil)
    end
    private :transition_finding_rendered

    def transition_analysis_failed(failure)
      with(outcome: :analysis_failed, selected_finding: nil, failure: failure)
    end
    private :transition_analysis_failed
  end

  Run::TRANSITIONS = {
    pending: %i[finding_rendered nothing_to_report analysis_failed].freeze
  }.freeze
end
