require "spec_helper"
require "set"

# Spec source: snoot.allium -- surface CLI
#   facing operator: Operator
#   provides: RunInvoked(operator, paths)
RSpec.describe "CLI surface" do
  describe "surface-actor.CLI" do
    it "is accessible to an Operator" do
      skip "bridge: CLI surface not implemented"
      operator = build_operator
      expect(Snoot::CLI.for(operator)).not_to be_nil
    end

    it "is not accessible to a non-Operator (e.g. ReportConsumer)" do
      skip "bridge: CLI surface not implemented"
      consumer = build_report_consumer
      expect { Snoot::CLI.for(consumer) }.to raise_error(StandardError)
    end
  end

  describe "surface-provides.CLI" do
    it "exposes RunInvoked(operator, paths) when invoked by an Operator" do
      skip "bridge: CLI surface + RunInvoked trigger not implemented"
      operator = build_operator
      paths = Set[Snoot::Path.new(raw: "lib/foo.rb")]
      events = capture_emitted_events { Snoot::CLI.for(operator).run_invoked(paths) }
      expect(events).to include(have_attributes(name: :run_invoked, paths: paths))
    end
  end

  # Bridge helpers
  def build_operator;          raise "TODO"; end
  def build_report_consumer;   raise "TODO"; end
  def capture_emitted_events(&_blk); raise "TODO"; end
end
