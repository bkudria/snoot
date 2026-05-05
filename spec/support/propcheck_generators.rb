# frozen_string_literal: true

require "prop_check"

module Snoot
  module Spec
    # PropCheck generators for AnalyseRun input mixes. Used by `:pbt`-tagged
    # invariant specs. Real reek smell-type names are drawn so that
    # Snoot.vendored_doc (production) and FakeOrchestration#vendored_doc
    # (fake) agree on which smells are documented.
    module PropCheckGenerators
      include Snoot::Spec::Factories

      REAL_REEK_TYPES = %w[FeatureEnvy TooManyMethods DataClump UncommunicativeMethodName].freeze
      DOC_LESS_TYPES  = %w[UnknownSmell ImaginaryFlaw].freeze

      module_function

      def smell_type_name_gen
        g = PropCheck::Generators
        # 75% real reek types, 25% doc-less.
        g.frequency(
          3 => g.one_of(*REAL_REEK_TYPES.map { |n| g.constant(n) }),
          1 => g.one_of(*DOC_LESS_TYPES.map { |n| g.constant(n) })
        )
      end

      def smell_gen
        smell_type_name_gen.map { |name| build_smell(smell_type: build_smell_type(name: name)) }
      end

      def complexity_hit_gen
        PropCheck::Generators.constant(nil).map { build_complexity_hit }
      end

      def duplication_cluster_gen
        PropCheck::Generators.constant(nil).map { build_duplication_cluster }
      end

      def analyse_run_inputs_gen
        g = PropCheck::Generators
        g.tuple(
          g.array(smell_gen, max: 5).map(&:to_set),
          g.array(complexity_hit_gen, max: 3).map(&:to_set),
          g.array(duplication_cluster_gen, max: 3).map(&:to_set),
          g.boolean
        )
      end

      def real_reek_doc_map
        REAL_REEK_TYPES.to_h do |name|
          [name, Snoot.vendored_doc(Snoot::SmellType.new(name: name)) || "## stub"]
        end
      end

      def run_analyse_with_inputs(inputs)
        smells, complexities, duplications, raise_flag = inputs
        orch = fake_orchestration(
          smells: smells, complexities: complexities, duplications: duplications,
          vendored_docs: real_reek_doc_map,
          reek_raises: raise_flag ? StandardError.new("boom") : nil
        )
        run, _events = Snoot::AnalyseRun.invoke(Set[build_path], orchestration: orch)
        run
      end
    end
  end
end
