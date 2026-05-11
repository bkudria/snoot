# frozen_string_literal: true

# Top-level namespace for the snoot gem. See `snoot.allium` for the
# behavioural specification this implementation realises.
module Snoot
end

require "snoot/version"
require "snoot/state_error"
require "snoot/path"
require "snoot/location"
require "snoot/smell_type"
require "snoot/smell"
require "snoot/complexity_hit"
require "snoot/duplication_cluster"
require "snoot/analyser_failure"
require "snoot/sources"
require "snoot/run"
require "snoot/analyse_run"
require "snoot/analyse_run/result"
require "snoot/analyse_run/sources_view"
require "snoot/render_report"
require "snoot/analyser_orchestration"
require "snoot/analyser_orchestration/result_mapping"
require "snoot/analyser_orchestration/default"
require "snoot/cli"
