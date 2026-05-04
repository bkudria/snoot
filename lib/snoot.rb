# frozen_string_literal: true

module Snoot
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
