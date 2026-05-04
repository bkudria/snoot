require "reek"

module Snoot
  module AnalyserOrchestration
    # Default is the production adapter for AnalyserOrchestration. It
    # invokes the real Reek/Flog/Flay APIs in-process (no shellouts) and
    # resolves vendored_doc against the reek docs vendored at
    # data/reek_docs/<PascalCase-Hyphen>.md (synced via `rake docs:sync`,
    # pinned to the bundled reek version). Slice 10A implements
    # reek_analyse, vendored_doc, describe_location; flog_analyse and
    # flay_analyse arrive in slice 10B.
    class Default
      DOCS_ROOT = File.expand_path("../../../data/reek_docs", __dir__).freeze

      def reek_analyse(paths)
        paths.each_with_object(Set[]) do |path, smells|
          examiner = Reek::Examiner.new(Pathname.new(path.raw))
          examiner.smells.each do |w|
            next if w.lines.nil? || w.lines.empty?

            smells << build_smell(w)
          end
        end
      end

      # TODO(slice 10B): replace empty-Set stubs with real Flog/Flay output.
      def flog_analyse(_paths)
        Set[]
      end

      def flay_analyse(_paths)
        Set[]
      end

      def describe_location(location)
        "#{location.path.raw}:#{location.line_start}-#{location.line_end}"
      end

      def vendored_doc(smell_type)
        path = File.join(DOCS_ROOT, "#{hyphenate(smell_type.name)}.md")
        File.exist?(path) ? File.read(path) : nil
      end

      private

      def build_smell(warning)
        Smell.new(
          smell_type: SmellType.new(name: warning.smell_type),
          location: Location.new(
            path: Path.new(raw: warning.source),
            line_start: warning.lines.first,
            line_end: warning.lines.last
          ),
          message: warning.message
        )
      end

      def hyphenate(name)
        name.gsub(/([a-z])([A-Z])/, '\1-\2')
      end
    end
  end
end
