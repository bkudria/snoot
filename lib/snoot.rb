# frozen_string_literal: true

# Top-level namespace for the snoot gem. See `snoot.allium` for the
# behavioural specification this implementation realises.
module Snoot
  # Surfaces the AnalyserOrchestration contract's vendored_doc at module
  # scope, backed by a memoised default orchestration. Lazy so the
  # AnalyserOrchestration::Default constant is resolved at call time, after
  # the requires below have run.
  def self.vendored_doc(smell_type)
    (@default_orchestration ||= AnalyserOrchestration::Default.new).vendored_doc(smell_type)
  end
end

require "snoot/version"
require "snoot/state_error"
require "snoot/path"
require "snoot/location"
require "snoot/smell_type"
require "snoot/finding"
require "snoot/smell"
require "snoot/complexity_hit"
require "snoot/duplication_cluster"
require "snoot/run"
require "snoot/analyse_run"
require "snoot/render_report"
require "snoot/report_consumer"
require "snoot/report_reader"
require "snoot/operator"
require "snoot/analyser_orchestration"
require "snoot/analyser_orchestration/default"
require "snoot/cli"
require "snoot/cli/argv"
