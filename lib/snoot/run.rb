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
      enforce_field_when!(:selected_finding, outcome: :finding_rendered)
      enforce_field_when!(:failure, outcome: :analysis_failed)
    end

    def transition_to(target, selected_finding: nil, failure: nil)
      raise StateError, "transition #{outcome} -> #{target} is not declared" unless outcome == :pending

      with(outcome: target, selected_finding: selected_finding, failure: failure)
    end

    private

    def enforce_field_when!(field_name, outcome:)
      field_value = public_send(field_name)
      if self.outcome == outcome
        raise StateError, "#{field_name} required for :#{outcome}" unless field_value
      elsif field_value
        raise StateError,
              "#{field_name} only permitted when outcome = :#{outcome} (got #{self.outcome.inspect})"
      end
    end
  end
end
