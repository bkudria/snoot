require "spec_helper"
require "set"

# Spec source: snoot.allium -- entity Run with transitions on outcome and
# state-dependent field selected_finding (when outcome = finding_rendered).
RSpec.describe "Run entity" do
  describe "entity-fields.Run" do
    it "declares paths and outcome" do
      run = Snoot::Run.new(paths: Set[], outcome: :pending)
      expect(run.paths).to be_a(Set)
      expect(run.outcome).to eq(:pending)
    end
  end

  describe "when-presence.Run.selected_finding" do
    it "is present when outcome = :finding_rendered" do
      run = build_run_at(:finding_rendered)
      expect(run.selected_finding).not_to be_nil
    end

    it "is absent (nil or guarded) when outcome != :finding_rendered" do
      [:pending, :nothing_to_report, :analysis_failed].each do |state|
        run = build_run_at(state)
        # Design choice (slice 2): access raises rather than returns nil,
        # mirroring the Allium `when` guard semantics. Message must mention
        # `finding_rendered` so the cause is obvious.
        expect { run.selected_finding }.to raise_error(/finding_rendered/i)
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
  end

  describe "transition-rejected.Run.outcome" do
    it "rejects undeclared transitions (e.g. finding_rendered -> pending)" do
      run = build_run_at(:finding_rendered)
      expect { transition!(run, to: :pending) }.to raise_error(Snoot::StateError)
    end
  end

  describe "transition-terminal.Run.outcome" do
    it "terminal states have no outbound transitions" do
      terminals = [:finding_rendered, :nothing_to_report, :analysis_failed]
      all_states = [:pending] + terminals
      terminals.each do |from|
        all_states.each do |to|
          next if to == from
          expect { transition!(build_run_at(from), to: to) }
            .to raise_error(Snoot::StateError),
                "expected #{from} -> #{to} to be rejected"
        end
      end
    end
  end
end
