# frozen_string_literal: true

require "spec_helper"

# Spec source: slice 11 -- Snoot::CLI::Argv (exe argv handler)
RSpec.describe Snoot::CLI::Argv do
  let(:stdout) { null_io }
  let(:stderr) { null_io }
  let(:smelly_ruby) do
    <<~RUBY
      class Dirty
        def smelly(x)
          x.a + x.b + x.c + x.d
        end
      end
    RUBY
  end
  let(:smell_free_ruby) do
    <<~RUBY
      # A trivial, smell-free class for the empty-result test.
      class Tiny
      end
    RUBY
  end

  def run_argv(argv, orchestration: Snoot::AnalyserOrchestration::Default)
    streams = Snoot::CLI::Streams.new(stdout: stdout, stderr: stderr)
    pipeline = Snoot::CLI::Pipeline.new(orchestration: orchestration, streams: streams)
    described_class.run(argv, pipeline: pipeline)
  end

  describe ".run" do
    it "writes the version to stdout and returns 0 for --version", :aggregate_failures do
      code = run_argv(["--version"])
      expect(code).to eq(0)
      expect(stdout.string).to eq("snoot #{Snoot::VERSION}\n")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stdout and returns 0 for --help", :aggregate_failures do
      code = run_argv(["--help"])
      expect(code).to eq(0)
      expect(stdout.string).to include("Usage: snoot", "[paths...]")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stderr and returns 1 for an unknown flag", :aggregate_failures do
      code = run_argv(["--unknown-flag"])
      expect(code).to eq(1)
      expect(stderr.string).to include("Usage: snoot")
      expect(stdout.string).to be_empty
    end

    it "passes a single Ruby file path through the pipeline (nothing_to_report)", :aggregate_failures do
      with_ruby_tempfile(smell_free_ruby) do |path|
        code = run_argv([path])
        expect(code).to eq(0)
        expect([stdout.string, stderr.string]).to eq([Snoot::CLI::NOTHING_TO_REPORT, ""])
      end
    end

    it "exits 1 with a doc + Instances report on stdout when a Smell finding is rendered", :aggregate_failures do
      with_ruby_tempfile(smelly_ruby) do |path|
        code = run_argv([path])
        expect(code).to eq(1)
        expect(stdout.string).to include("## Instances\n\n", path)
      end
    end

    it "defaults empty argv to Dir['lib/**/*.rb'] in cwd", :aggregate_failures do
      with_seeded_lib("dirty.rb", smelly_ruby) do
        code = run_argv([])
        expect(code).to eq(1)
        expect(stdout.string).to include("## Instances\n\n")
      end
    end

    it "exits 1 with stderr message when analysis fails", :aggregate_failures do
      orchestration = fake_orchestration(reek_raises: StandardError.new("boom"))
      code = run_argv(["lib/foo.rb"], orchestration: orchestration)
      expect(code).to eq(1)
      expect(stderr.string).to include("analysis failed:", "boom")
      expect(stdout.string).to be_empty
    end
  end
end
