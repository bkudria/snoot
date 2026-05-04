require "spec_helper"
require "fileutils"
require "tmpdir"

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
      expect(stdout.string).to include("[paths...]")
      expect(stderr.string).to be_empty
    end

    it "writes usage to stderr and returns 1 for an unknown flag" do
      code = Snoot::CLI::Argv.run(["--unknown-flag"], stdout: stdout, stderr: stderr)
      expect(code).to eq(1)
      expect(stderr.string).to include("Usage: snoot")
      expect(stdout.string).to be_empty
    end

    it "passes a single Ruby file path through the pipeline (nothing_to_report)" do
      smell_free = <<~RUBY
        # A trivial, smell-free class for the empty-result test.
        class Tiny
        end
      RUBY
      with_ruby_tempfile(smell_free) do |path|
        code = Snoot::CLI::Argv.run([path], stdout: stdout, stderr: stderr)
        expect(code).to eq(0)
        expect(stdout.string).to eq(Snoot::CLI::NOTHING_TO_REPORT)
        expect(stderr.string).to be_empty
      end
    end

    it "exits 1 with a doc + Instances report on stdout when a Smell finding is rendered" do
      smelly = <<~RUBY
        class Dirty
          def smelly(x)
            x.a + x.b + x.c + x.d
          end
        end
      RUBY
      with_ruby_tempfile(smelly) do |path|
        code = Snoot::CLI::Argv.run([path], stdout: stdout, stderr: stderr)
        expect(code).to eq(1)
        expect(stdout.string).not_to be_empty
        expect(stdout.string).not_to eq(Snoot::CLI::NOTHING_TO_REPORT)
        expect(stdout.string).to include("## Instances\n\n")
        expect(stdout.string).to include(path)
      end
    end

    it "defaults empty argv to Dir['lib/**/*.rb'] in cwd" do
      smelly = <<~RUBY
        class Dirty
          def smelly(x)
            x.a + x.b + x.c + x.d
          end
        end
      RUBY
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p("lib")
          File.write("lib/dirty.rb", smelly)
          code = Snoot::CLI::Argv.run([], stdout: stdout, stderr: stderr)
          expect(code).to eq(1)
          expect(stdout.string).not_to be_empty
          expect(stdout.string).not_to eq(Snoot::CLI::NOTHING_TO_REPORT)
        end
      end
    end

    it "exits 1 with stderr message when analysis fails" do
      orchestration = fake_orchestration(reek_raises: StandardError.new("boom"))
      code = Snoot::CLI::Argv.run(
        ["lib/foo.rb"],
        stdout: stdout, stderr: stderr, orchestration: orchestration
      )
      expect(code).to eq(1)
      expect(stderr.string).to include("analysis failed:")
      expect(stderr.string).to include("boom")
      expect(stdout.string).to be_empty
    end
  end
end
