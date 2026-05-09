# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- entity Run with transitions on outcome and
# state-dependent field selected_finding (when outcome = finding_rendered).
RSpec.describe Snoot::Run do
  describe "entity-fields.Run" do
    it "declares paths and outcome", :aggregate_failures do
      run = described_class.new(paths: Set[], outcome: :pending)
      expect(run.paths).to be_a(Set)
      expect(run.outcome).to eq(:pending)
    end

    it "carries an AnalyserFailure on .failure when outcome = :analysis_failed" do
      af = Snoot::AnalyserFailure.new(analyser: :reek, message: "boom")
      run = described_class.new(paths: Set[], outcome: :analysis_failed, failure: af)
      expect(run.failure).to eq(af)
    end
  end

  describe "construction-guard.Run.selected_finding" do
    it "rejects outcome=:finding_rendered with nil selected_finding" do
      expect do
        described_class.new(paths: Set[], outcome: :finding_rendered, selected_finding: nil)
      end.to raise_error(Snoot::StateError, /selected_finding/)
    end
  end

  describe "construction-guard.Run.failure" do
    let(:af) { Snoot::AnalyserFailure.new(analyser: :reek, message: "boom") }
    let(:finding) { build_smell }

    def expect_state_error(regex, **attrs)
      expect { described_class.new(paths: Set[], **attrs) }.to raise_error(Snoot::StateError, regex)
    end

    it "rejects outcome=:analysis_failed with nil failure" do
      expect_state_error(/failure/, outcome: :analysis_failed)
    end

    it "rejects failure: when outcome != :analysis_failed", :aggregate_failures do
      # Allium `when` clause is two-sided: present iff outcome matches.
      %i[pending nothing_to_report].each do |state|
        expect_state_error(/failure/, outcome: state, failure: af)
      end
      expect_state_error(/failure/, outcome: :finding_rendered, selected_finding: finding, failure: af)
    end

    it "rejects selected_finding: when outcome != :finding_rendered", :aggregate_failures do
      # Allium `when` clause is two-sided: present iff outcome matches.
      %i[pending nothing_to_report].each do |state|
        expect_state_error(/selected_finding/, outcome: state, selected_finding: finding)
      end
      expect_state_error(/selected_finding/, outcome: :analysis_failed, selected_finding: finding, failure: af)
    end
  end

  describe "when-presence.Run.selected_finding" do
    it "is present when outcome = :finding_rendered" do
      run = build_run_at(:finding_rendered)
      expect(run.selected_finding).not_to be_nil
    end

    it "is nil when outcome != :finding_rendered" do
      %i[pending nothing_to_report analysis_failed].each do |state|
        run = build_run_at(state)
        expect(run.selected_finding).to be_nil
      end
    end
  end

  describe "when-presence.Run.failure" do
    it "is present when outcome = :analysis_failed" do
      run = build_run_at(:analysis_failed)
      expect(run.failure).to be_a(Snoot::AnalyserFailure)
    end

    it "is nil at any other outcome", :aggregate_failures do
      %i[pending nothing_to_report finding_rendered].each do |state|
        run = build_run_at(state)
        expect(run.failure).to(be_nil, "expected #{state}.failure to be nil")
      end
    end
  end

  describe "transition-edge.Run.outcome" do
    it "pending -> finding_rendered is reachable via AnalyseRun" do
      run = drive_to(:finding_rendered)
      expect(run.outcome).to eq(:finding_rendered)
    end

    it "pending -> nothing_to_report is reachable via AnalyseRun" do
      run = drive_to(:nothing_to_report)
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "pending -> analysis_failed is reachable via AnalyseRun" do
      run = drive_to(:analysis_failed)
      expect(run.outcome).to eq(:analysis_failed)
    end

    it "transition_to(:analysis_failed, failure:) carries the failure onto the new Run" do
      af = Snoot::AnalyserFailure.new(analyser: :flog, message: "score too high")
      run = described_class.new(paths: Set[], outcome: :pending)
      moved = run.transition_to(:analysis_failed, failure: af)
      expect(moved.failure).to eq(af)
    end

    it "transition_to(:analysis_failed) without a failure raises StateError" do
      run = described_class.new(paths: Set[], outcome: :pending)
      expect { run.transition_to(:analysis_failed) }
        .to raise_error(Snoot::StateError, /failure/)
    end

    it "transition_to(:finding_rendered) without a selected_finding raises StateError" do
      run = described_class.new(paths: Set[], outcome: :pending)
      expect { run.transition_to(:finding_rendered) }
        .to raise_error(Snoot::StateError, /selected_finding/)
    end
  end

  describe "transition-rejected.Run.outcome" do
    it "rejects undeclared transitions (e.g. finding_rendered -> pending)" do
      run = build_run_at(:finding_rendered)
      expect { transition!(run, to: :pending) }.to raise_error(Snoot::StateError)
    end
  end

  describe "transition-terminal.Run.outcome" do
    def each_terminal_invalid_transition
      terminals = %i[finding_rendered nothing_to_report analysis_failed]
      all_states = [:pending] + terminals
      terminals.each do |from|
        all_states.each { |to| yield(from, to) unless from == to }
      end
    end

    it "terminal states have no outbound transitions" do
      each_terminal_invalid_transition do |from, to|
        expect { transition!(build_run_at(from), to: to) }
          .to raise_error(Snoot::StateError), "#{from} -> #{to} should be rejected"
      end
    end
  end
end
