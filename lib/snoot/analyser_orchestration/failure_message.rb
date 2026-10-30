# frozen_string_literal: true

module Snoot
  module AnalyserOrchestration
    # FailureMessage turns an analyser's exception into the one-line
    # message an AnalyserFailure carries.
    module FailureMessage
      module_function

      def for(error)
        detail = cause_detail(error.cause)
        message = error.message
        message = "#{message} (#{detail})" if detail && !message.include?(detail)
        message.gsub(/\s*\n\s*/, " ")
      end

      # reek wraps parser and IO errors in its own, which name the file but
      # not the line or reason; the wrapped cause carries those.
      def cause_detail(cause)
        return unless cause

        cause.respond_to?(:diagnostic) ? cause.diagnostic.render.first : cause.message
      end
    end
  end
end
