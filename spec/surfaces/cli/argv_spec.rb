require "spec_helper"

# Spec source: slice 11 -- Snoot::CLI::Argv (exe argv handler)
RSpec.describe "Snoot::CLI::Argv" do
  let(:stdout) { null_io }
  let(:stderr) { null_io }

  describe ".run" do
    it "writes the version to stdout and returns 0 for --version" do
      code = Snoot::CLI::Argv.run(["--version"], stdout: stdout, stderr: stderr)
      expect(code).to eq(0)
      expect(stdout.string).to eq("snoot #{Snoot::VERSION}\n")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stdout and returns 0 for --help" do
      code = Snoot::CLI::Argv.run(["--help"], stdout: stdout, stderr: stderr)
      expect(code).to eq(0)
      expect(stdout.string).to include("Usage: snoot")
      expect(stdout.string).to include("not yet implemented")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stderr and returns 1 for unknown argv" do
      code = Snoot::CLI::Argv.run(["lib/foo.rb"], stdout: stdout, stderr: stderr)
      expect(code).to eq(1)
      expect(stderr.string).to include("Usage: snoot")
      expect(stdout.string).to be_empty
    end
  end
end
