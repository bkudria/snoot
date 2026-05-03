module Snoot
  # ReportReader is the surface from snoot.allium that exposes a
  # finding-rendered Run's selected_finding (and its kind) to a
  # ReportConsumer. .for returns a Reader when run.outcome is
  # :finding_rendered, or nil otherwise. The Reader is a thin view --
  # Run remains the source of truth.
  module ReportReader
    Reader = Data.define(:run) do
      def selected_finding
        run.selected_finding
      end

      def kind
        run.selected_finding.kind
      end
    end

    module_function

    def for(_consumer, run:)
      return nil unless run.outcome == :finding_rendered

      Reader.new(run: run)
    end
  end
end
