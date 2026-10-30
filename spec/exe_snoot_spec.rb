# frozen_string_literal: true

require "spec_helper"
require "open3"

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
    expect(out.lines.last).to start_with("snoot-status: finding_rendered category=smell type=")
    expect(err).to be_empty
  end

  it "ends a clean run with the nothing_to_report status line and exits 0", :aggregate_failures do
    out, _err, status = with_ruby_tempfile("# frozen_string_literal: true\n") do |path|
      Open3.capture3("bundle", "exec", exe, path)
    end
    expect(status.exitstatus).to eq(0)
    expect(out.lines.last).to eq("snoot-status: nothing_to_report\n")
  end

  it "exits 64 with no status line for a missing path", :aggregate_failures do
    out, err, status = Open3.capture3("bundle", "exec", exe, "does-not-exist.rb")
    expect(status.exitstatus).to eq(64)
    expect(out).to be_empty
    expect(err).to eq("snoot: no such file or directory: does-not-exist.rb\n")
  end
end
