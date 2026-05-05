# frozen_string_literal: true

module Snoot
  module Spec
    class FakeOrchestration
      # rubocop:disable Metrics/ParameterLists
      def initialize(smells: Set[], complexities: Set[], duplications: Set[],
                     vendored_docs: {},
                     reek_raises: nil, flog_raises: nil, flay_raises: nil)
        @smells = smells
        @complexities = complexities
        @duplications = duplications
        @vendored_docs = vendored_docs
        @reek_raises = reek_raises
        @flog_raises = flog_raises
        @flay_raises = flay_raises
      end
      # rubocop:enable Metrics/ParameterLists

      def reek_analyse(_paths)
        raise @reek_raises if @reek_raises

        @smells
      end

      def flog_analyse(_paths)
        raise @flog_raises if @flog_raises

        @complexities
      end

      def flay_analyse(_paths)
        raise @flay_raises if @flay_raises

        @duplications
      end

      def vendored_doc(smell_type)
        @vendored_docs[smell_type.name]
      end

      def significant_smells(smells) = smells
      def significant_complexities(complexities) = complexities
      def significant_duplications(duplications) = duplications
    end
  end
end
