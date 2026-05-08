# frozen_string_literal: true

module Snoot
  # Smell is the Finding entity from snoot.allium representing a single
  # Reek smell instance: its SmellType, the Location where it was
  # raised, and the Reek-supplied message. Smells are ranked by
  # frequency of their smell_type within a Run.
  Smell = Data.define(:smell_type, :location, :message) do
    include Finding

    def kind = Smell

    def self.from_reek_warning(warning)
      lines = warning.lines
      new(
        smell_type: SmellType.new(name: warning.smell_type),
        location: Location.new(
          path: Path.new(raw: warning.source),
          line_start: lines.first,
          line_end: lines.last
        ),
        message: "#{warning.context} #{warning.message}"
      )
    end
  end
end
