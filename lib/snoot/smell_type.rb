# frozen_string_literal: true

module Snoot
  # SmellType is the value type from snoot.allium identifying a Reek
  # smell category (e.g. "IrresponsibleModule") by name. Used to group
  # Smells for ranking and to look up vendored documentation.
  SmellType = Data.define(:name)
end
