# frozen_string_literal: true

# SimpleCov configuration loaded by spec_helper.rb.

SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
  minimum_coverage line: 99, branch: 90
end
