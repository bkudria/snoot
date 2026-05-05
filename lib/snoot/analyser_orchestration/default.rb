# frozen_string_literal: true

require "bigdecimal"
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
    # threshold (16). Stateless: implemented as a module of module
    # functions, used as the orchestration value directly (no `.new`).
    module Default
      DOCS_ROOT = File.expand_path("../../../data/reek_docs", __dir__).freeze
      DOC_FILENAME_PATTERN = /([a-z])([A-Z])/

      SMELL_TYPE_INSTANCE_FLOOR = 2
      COMPLEXITY_SCORE_FLOOR = BigDecimal("25")

      module_function

      def reek_analyse(paths)
        paths.flat_map { |path| reek_smells_for(path) }.to_set
      end

      def reek_smells_for(path)
        examiner = Reek::Examiner.new(Pathname.new(path.raw))
        examiner.smells.filter_map do |warning|
          next unless warning.lines&.any?

          Smell.from_reek_warning(warning)
        end
      end

      def flog_analyse(paths)
        flog = Flog.new
        flog.flog(*paths.map(&:raw))
        flog.totals.filter_map do |class_method, score|
          ComplexityHit.from_flog_entry(
            class_method: class_method, score: score,
            raw_location: flog.method_locations[class_method]
          )
        end.to_set
      end

      def flay_analyse(paths)
        flay = Flay.new
        flay.process(*paths.map(&:raw))
        flay.analyze.each_with_object(Set[]) do |item, clusters|
          clusters << DuplicationCluster.from_flay_item(item)
        end
      end

      def vendored_doc(smell_type)
        path = File.join(DOCS_ROOT, "#{smell_type.name.gsub(DOC_FILENAME_PATTERN, '\1-\2')}.md")
        File.exist?(path) ? File.read(path) : nil
      end

      def significant_smells(smells)
        counts = smells.group_by(&:smell_type).transform_values(&:size)
        smells.select { |smell| counts[smell.smell_type] >= SMELL_TYPE_INSTANCE_FLOOR }.to_set
      end

      def significant_complexities(complexities)
        complexities.select { |hit| hit.score >= COMPLEXITY_SCORE_FLOOR }.to_set
      end

      def significant_duplications(duplications) = duplications
    end
  end
end
