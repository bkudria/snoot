# frozen_string_literal: true

module Snoot
  # StateError signals a violation of the Run state machine: an
  # undeclared outcome transition, a missing selected_finding when
  # transitioning to :finding_rendered, or access to selected_finding
  # before that outcome is reached.
  class StateError < StandardError
  end
end
