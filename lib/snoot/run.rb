# frozen_string_literal: true

module Snoot
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
        raise StateError, "selected_finding required for :finding_rendered" if selected_finding.nil?

        with(outcome: target, selected_finding: selected_finding)
      else
        with(outcome: target, selected_finding: nil)
      end
    end
  end
end
