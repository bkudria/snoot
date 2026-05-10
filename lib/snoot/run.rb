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
      validate_presence_invariants!
    end

    def validate_presence_invariants!
      Run::PRESENCE_INVARIANTS.each do |required_outcome, field_name|
        enforce_presence_invariant!(field_name, required_outcome)
      end
    end
    private :validate_presence_invariants!

    def enforce_presence_invariant!(field_name, required_outcome)
      field_value = public_send(field_name)
      if outcome == required_outcome
        raise StateError, "#{field_name} required for :#{required_outcome}" unless field_value
      elsif field_value
        raise StateError,
              "#{field_name} only permitted when outcome = :#{required_outcome} (got #{outcome.inspect})"
      end
    end
    private :enforce_presence_invariant!

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

  Run::PRESENCE_INVARIANTS = {
    finding_rendered: :selected_finding,
    analysis_failed: :failure
  }.freeze

  Run::TRANSITIONS = {
    pending: %i[finding_rendered nothing_to_report analysis_failed].freeze
  }.freeze
end
