# frozen_string_literal: true

require "spec_helper"
require "open3"

# Spec source: snoot.allium -- surface CLI (subprocess smoke test via exe/snoot).
# Subject is the executable script, not a single class.
RSpec.describe "exe/snoot" do # rubocop:disable RSpec/DescribeClass
  let(:exe) { File.expand_path("../exe/snoot", __dir__) }
  let(:smelly_source) do
    <<~RUBY
      class Dirty
        def smelly_a(x)
          x.a + x.b + x.c + x.d
        end

        def smelly_b(y)
          y.a + y.b + y.c + y.d
        end
      end
    RUBY
  end
  let(:smelly_run_result) do
    output = nil
    with_ruby_tempfile(smelly_source) do |path|
      output = Open3.capture3("bundle", "exec", exe, path)
    end
    output
  end

  it "prints the version and exits 0 for --version", :aggregate_failures do
    out, err, status = Open3.capture3("bundle", "exec", exe, "--version")
    expect(status.exitstatus).to eq(0)
    expect(out).to eq("snoot #{Snoot::VERSION}\n")
    expect(err).to be_empty
  end

  it "drives the pipeline against a smelly path and exits 1", :aggregate_failures do
    out, err, status = smelly_run_result
    expect(status.exitstatus).to eq(1)
    expect(out).not_to be_empty
    expect(err).to be_empty
  end
end
