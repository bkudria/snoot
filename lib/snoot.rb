# frozen_string_literal: true

# Top-level namespace for the snoot gem. See `snoot.allium` for the
# behavioural specification this implementation realises.
module Snoot
end

require "snoot/version"
require "snoot/state_error"
require "snoot/value_types"
require "snoot/findings"
require "snoot/analyser_result"
require "snoot/run"
require "snoot/analyse_run"
require "snoot/analyse_run/result"
require "snoot/render_report"
require "snoot/analyser_orchestration"
require "snoot/analyser_orchestration/result_mapping"
require "snoot/analyser_orchestration/default"
require "snoot/cli"
