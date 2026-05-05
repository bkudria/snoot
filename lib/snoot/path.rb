# frozen_string_literal: true

module Snoot
  # Path is the value type from snoot.allium wrapping a raw filesystem
  # path string supplied to a Run. Kept distinct from String so the
  # spec's path-typed slots stay traceable.
  Path = Data.define(:raw)
end
