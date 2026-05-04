# frozen_string_literal: true

# SimpleCov configuration loaded by spec_helper.rb.
#
# minimum_coverage is intentionally 0 during the spec-first phase: the bar
# exists (so the project's coverage ratchet is configured), but lib/ has no
# implementation yet, so a meaningful percentage cannot be computed. Raise
# this once a non-trivial portion of lib/ ships.

SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  minimum_coverage line: 0, branch: 0
end
