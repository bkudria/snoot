# frozen_string_literal: true

require "flay"
require "flog"
require "reek"

module Snoot
  module AnalyserOrchestration
    # Default is the production adapter for AnalyserOrchestration. It
    # invokes the real Reek/Flog/Flay APIs in-process (no shellouts) and
    # resolves vendored_doc against the reek docs vendored at
    # data/reek_docs/<PascalCase-Hyphen>.md (synced via `rake docs:sync`,
    # pinned to the bundled reek version). Flog scoring uses Flog's
    # default options (every scored method emits a ComplexityHit; selection
    # happens in AnalyseRun). Flay duplication uses Flay's default mass
    # threshold (16).
    class Default
      DOCS_ROOT = File.expand_path("../../../data/reek_docs", __dir__).freeze

      def reek_analyse(paths)
        paths.each_with_object(Set[]) do |path, smells|
          examiner = Reek::Examiner.new(Pathname.new(path.raw))
          examiner.smells.each do |warning|
            lines = warning.lines
            next if lines.nil? || lines.empty?

            smells << build_smell(warning)
          end
        end
      end

      def flog_analyse(paths)
        flog = Flog.new
        flog.flog(*paths.map(&:raw))
        flog.totals.each_with_object(Set[]) do |(class_method, score), hits|
          hit = build_complexity_hit(class_method, score, flog.method_locations[class_method])
          hits << hit unless hit.nil?
        end
      end

      def flay_analyse(paths)
        flay = Flay.new
        flay.process(*paths.map(&:raw))
        flay.analyze.each_with_object(Set[]) do |item, clusters|
          clusters << build_duplication_cluster(item)
        end
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
        lines = warning.lines
        Smell.new(
          smell_type: SmellType.new(name: warning.smell_type),
          location: Location.new(
            path: Path.new(raw: warning.source),
            line_start: lines.first,
            line_end: lines.last
          ),
          message: "#{warning.context} #{warning.message}"
        )
      end

      def hyphenate(name)
        name.gsub(/([a-z])([A-Z])/, '\1-\2')
      end

      def build_complexity_hit(class_method, score, raw_location)
        loc = parse_flog_location(raw_location)
        return nil if loc.nil?

        ComplexityHit.new(
          location: loc,
          method_name: class_method,
          score: BigDecimal(score.to_s)
        )
      end

      def build_duplication_cluster(item)
        DuplicationCluster.new(
          signature: item.structural_hash.to_s,
          locations: item.locations.each_with_object(Set[]) do |loc, set|
            line = loc.line
            set << Location.new(path: Path.new(raw: loc.file), line_start: line, line_end: line)
          end
        )
      end

      # Flog stores method locations as "file:line" or "file:line-line_max".
      # Returns nil when the entry is missing (e.g. main#none) so callers
      # can skip top-level expressions that lack a method-level location.
      def parse_flog_location(raw)
        return nil if raw.nil? || raw.empty?

        file, range = raw.split(":", 2)
        return nil if file.nil? || range.nil?

        line_start, _line_end = range.split("-", 2).map(&:to_i)
        Location.new(
          path: Path.new(raw: file),
          line_start: line_start,
          line_end: line_start
        )
      end
    end
  end
end
