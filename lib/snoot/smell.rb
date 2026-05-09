# frozen_string_literal: true

module Snoot
  # Smell is the Finding entity from snoot.allium representing a single
  # Reek smell instance: its SmellType, the Location where it was
  # raised, and the Reek-supplied message. Smells are ranked by
  # frequency of their smell_type within a Run.
  Smell = Data.define(:smell_type, :location, :message) do
    include Finding

    def kind = Smell
  end
end
