# frozen_string_literal: true

module Snoot
  # Operator is the external entity from snoot.allium that initiates a
  # CLI invocation. The spec declares no fields and no narrowing
  # behaviour beyond the type itself, so the type is a structural marker.
  Operator = Data.define
end
