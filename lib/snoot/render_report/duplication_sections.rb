# frozen_string_literal: true

module Snoot
  module RenderReport
    # The sections of a DuplicationCluster report. The context lists every
    # copy's span, then the code of one copy when the copies are identical
    # or of the first few when they differ, so the variation is visible.
    module DuplicationSections
      SIMILAR_COPIES_SHOWN = 3
      COPY_MAX_LINES = 20
      DOC = "Structural duplication suggests an extracted abstraction is missing. " \
            "Consider whether the duplicated shape belongs to a single helper, " \
            "module, or value type."

      module_function

      def build(cluster)
        {
          header: header(cluster),
          finding_context: [locations(cluster), *code(cluster)].join("\n\n"),
          doc: DOC
        }
      end

      def header(cluster)
        kind = cluster.identical ? "Identical" : "Similar"
        "#{kind} code (:#{cluster.node_type}) in #{cluster.size} locations, " \
          "mass #{cluster.mass} (#{cluster.copy_mass} per copy)"
      end

      def locations(cluster)
        ["Locations:", *cluster.locations.sort_by { |location| sort_key(location) }.map(&:description)].join("\n")
      end

      def code(cluster)
        excerpts = cluster.copies.sort_by { |copy| sort_key(copy.location) }.filter_map { |copy| excerpt(copy) }
        return [] if excerpts.empty?

        shown = excerpts.take(cluster.identical ? 1 : SIMILAR_COPIES_SHOWN)
        [[code_heading(cluster, shown.size), *shown].join("\n")]
      end

      def code_heading(cluster, shown_count)
        copies = cluster.size
        cluster.identical ? "Code (identical in all #{copies} copies):" : "Code (#{shown_count} of #{copies} copies):"
      end

      def excerpt(copy)
        lines = SourceExcerpt.block(copy.source_lines, max_lines: COPY_MAX_LINES)
        [copy.location.description, *lines].join("\n") unless lines.empty?
      end

      def sort_key(location)
        [location.path.raw, location.line_start]
      end
    end
  end
end
