# frozen_string_literal: true

module Snoot
  # StateError signals a violation of the Run state machine: an
  # undeclared outcome transition, or a missing/extraneous
  # selected_finding or failure relative to the run's outcome.
  class StateError < StandardError
  end
end
