# frozen_string_literal: true

require "spec_helper"
require "open3"

# Spec source: slice 11 -- exe/snoot subprocess smoke test.
# Subject is the executable script, not a single class.
RSpec.describe "exe/snoot" do # rubocop:disable RSpec/DescribeClass
  let(:exe) { File.expand_path("../exe/snoot", __dir__) }

  it "prints the version and exits 0 for --version" do
    out, err, status = Open3.capture3("bundle", "exec", exe, "--version")
    expect(status.exitstatus).to eq(0)
    expect(out).to eq("snoot #{Snoot::VERSION}\n")
    expect(err).to be_empty
  end

  it "drives the pipeline against a smelly path and exits 1" do
    smelly = <<~RUBY
      class Dirty
        def smelly(x)
          x.a + x.b + x.c + x.d
        end
      end
    RUBY
    with_ruby_tempfile(smelly) do |path|
      out, err, status = Open3.capture3("bundle", "exec", exe, path)
      expect(status.exitstatus).to eq(1)
      expect(out).not_to be_empty
      expect(err).to be_empty
    end
  end
end
