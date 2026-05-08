# frozen_string_literal: true

require "bigdecimal"

module Snoot
  # ComplexityHit is the Finding entity from snoot.allium representing a
  # single high-complexity method reported by Flog: a Location, the
  # offending method_name, and the BigDecimal score used for ranking.
  ComplexityHit = Data.define(:location, :method_name, :score) do
    include Finding

    def kind = ComplexityHit
    def doc = self.class::DOC

    # Flog stores method locations as "file:line" or "file:line-line_max".
    # Returns nil when the entry is missing (e.g. main#none) so callers
    # can skip top-level expressions that lack a method-level location.
    def self.from_flog_entry(class_method:, score:, raw_location:)
      file, range = raw_location.to_s.split(":", 2)
      return unless file && range

      line_start, = range.split("-", 2).map(&:to_i)
      new(
        location: Location.new(path: Path.new(raw: file), line_start: line_start, line_end: line_start),
        method_name: class_method,
        score: BigDecimal(score.to_s)
      )
    end
  end

  ComplexityHit::DOC =
    "High complexity hits indicate a method or class doing too much. " \
    "Consider extracting helpers, simplifying conditionals, or " \
    "splitting the responsibility across smaller units."
end
