require "spec_helper"
require "open3"

# Spec source: slice 11 -- exe/snoot subprocess smoke test
RSpec.describe "exe/snoot" do
  let(:exe) { File.expand_path("../exe/snoot", __dir__) }

  it "prints the version and exits 0 for --version" do
    out, err, status = Open3.capture3("bundle", "exec", exe, "--version")
    expect(status.exitstatus).to eq(0)
    expect(out).to eq("snoot #{Snoot::VERSION}\n")
    expect(err).to be_empty
  end
end
