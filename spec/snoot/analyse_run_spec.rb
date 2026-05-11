# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- rule AnalyseRun
#   when:    RunInvoked(paths)
#   ensures: Run.created with outcome in {finding_rendered, nothing_to_report,
#            analysis_failed}; emits SkippedDocLessSmellWarned when the
#            top-overall finding is a Smell whose vendored doc is missing.
RSpec.describe Snoot::AnalyseRun do
  describe "rule-success.AnalyseRun" do
    it "creates a Run terminating in one of the three declared outcomes", :aggregate_failures do
      paths = Set[Snoot::Path.new(raw: "lib/foo.rb")]
      run = invoke_analyse_run(paths)
      expect(run).to be_a(Snoot::Run)
      expect(run.paths).to eq(paths)
      expect(run.outcome).to(satisfy { |o| %i[finding_rendered nothing_to_report analysis_failed].include?(o) })
    end

    it "filters reek smells without vendored docs out of the candidate pool" do
      # Spec: documented_smell_findings = filter(smell_findings,
      #   s => vendored_doc(s.smell_type) != null)
      run = invoke_analyse_run_with_only_doc_less_smells
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "emits SkippedDocLessSmellWarned when the top-overall finding is a doc-less smell" do
      # Spec: nested if-guards on top_finding_overall narrow to Smell variant
      # before accessing smell_type, then check vendored_doc(smell_type) = null.
      events = capture_emitted_events { invoke_analyse_run_with_doc_less_top_smell }
      expect(events).to include(be_a(Snoot::AnalyseRun::SkippedDocLessSmellWarned))
    end

    it "emits SkippedDocLessSmellWarned with the terminal Run as event.run" do
      # Spec (snoot.allium:285-303): the warning trigger fires after run.outcome
      # is assigned, so the run: parameter references the resulting (terminal)
      # state. Per Allium semantics, trigger emission parameters reference the
      # resulting state regardless of textual ordering.
      events = capture_emitted_events { invoke_analyse_run_with_doc_less_top_smell }
      warning = events.find { |event| event.is_a?(Snoot::AnalyseRun::SkippedDocLessSmellWarned) }
      expect(warning.run.outcome).not_to eq(:pending)
    end

    it "invokes orchestration.analyse exactly once (no double analyser run)", :aggregate_failures do
      orch = fake_orchestration
      allow(orch).to receive(:analyse).and_call_original
      described_class.invoke(Set[build_path], orchestration: orch)
      expect(orch).to have_received(:analyse).once
    end
  end

  describe "result value" do
    it "returns an AnalyseRun::Result with run, events, smells accessors", :aggregate_failures do
      result = described_class.invoke(Set[build_path], orchestration: fake_orchestration)
      expect(result).to be_a(Snoot::AnalyseRun::Result)
      expect(result.run.outcome).to eq(:nothing_to_report)
      expect(result.events).to eq([])
      expect(result.smells).to eq(Set[])
    end
  end

  describe "rule-failure.AnalyseRun -- analyser raises" do
    def invoke_with(**raises)
      described_class.invoke(Set[build_path], orchestration: fake_orchestration(**raises))
    end

    it "drives the run to :analysis_failed with run.failure populated" do
      run = invoke_with(reek_raises: StandardError.new("reek-boom")).run
      expect(run).to have_attributes(outcome: :analysis_failed,
                                     failure: Snoot::AnalyserFailure.new(analyser: :reek, message: "reek-boom"))
    end

    it "tags the failure :flog when Flog raises" do
      run = invoke_with(flog_raises: StandardError.new("flog-boom")).run
      expect(run.failure).to have_attributes(analyser: :flog, message: "flog-boom")
    end

    it "tags the failure :flay when Flay raises" do
      run = invoke_with(flay_raises: StandardError.new("flay-boom")).run
      expect(run.failure).to have_attributes(analyser: :flay, message: "flay-boom")
    end

    it "still emits an :analysis_failed audit event referencing the failed run" do
      events = invoke_with(reek_raises: StandardError.new("boom")).events
      expect(events.find { |e| e.is_a?(Snoot::AnalyseRun::AnalysisFailed) }&.run&.outcome).to eq(:analysis_failed)
    end
  end

  describe "significance pre-filter" do
    # Sources#candidates and Sources#all must consult orchestration.significant_*
    # so floors filter out findings that don't warrant addressing before category
    # selection. These tests inject a fake whose significance methods drop
    # everything; today's behaviour ignores them and selects raw findings.
    let(:dropping_orchestration_class) do
      Class.new(Snoot::Spec::FakeOrchestration) do
        def significant_smells(_smells) = Set[]
        def significant_complexities(_complexities) = Set[]
        def significant_duplications(_duplications) = Set[]
      end
    end

    let(:documented_smell) { build_smell(smell_type: build_smell_type(name: "Documented")) }

    it "drops smells filtered out by significance, yielding nothing_to_report" do
      orch = dropping_orchestration_class.new(smells: Set[documented_smell],
                                              vendored_docs: { "Documented" => "## doc" })
      run = invoke_analyse_run(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "drops complexities filtered out by significance, yielding nothing_to_report" do
      hit = build_complexity_hit(score: BigDecimal("100.0"))
      orch = dropping_orchestration_class.new(complexities: Set[hit])
      run = invoke_analyse_run(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:nothing_to_report)
    end

    it "drops duplications filtered out by significance, yielding nothing_to_report" do
      cluster = build_duplication_cluster
      orch = dropping_orchestration_class.new(duplications: Set[cluster])
      run = invoke_analyse_run(Set[build_path], orchestration: orch)
      expect(run.outcome).to eq(:nothing_to_report)
    end
  end

  describe "deterministic tie-break" do
    # Inputs are constructed in reverse-canonical order so the existing
    # `.find { ... == max }` semantics (insertion-first) would yield the wrong
    # result. The picker must use an explicit secondary sort key to pick
    # canonically.
    def smell_at(type_name, path, line)
      build_smell(smell_type: build_smell_type(name: type_name),
                  location: build_location(path: build_path(raw: path), line_start: line))
    end

    def hit_at(score, path, line)
      build_complexity_hit(score: BigDecimal(score),
                           location: build_location(path: build_path(raw: path), line_start: line))
    end

    describe ".top_smell" do
      it "breaks smell-type ties by smell_type name ascending" do
        # Both types tie at count 2; FeatureEnvy < TooManyMethods alphabetically.
        # Reverse-ordered input so insertion order would pick TooManyMethods.
        smells = [smell_at("TooManyMethods", "z.rb", 1), smell_at("TooManyMethods", "a.rb", 9),
                  smell_at("FeatureEnvy", "b.rb", 1), smell_at("FeatureEnvy", "a.rb", 5)]
        expect(described_class.top_smell(smells).smell_type.name).to eq("FeatureEnvy")
      end

      it "breaks within-type ties by (path, line_start) ascending" do
        # Reverse-ordered input so today's `.find` returns the b.rb smell first.
        smells = [smell_at("FeatureEnvy", "b.rb", 1), smell_at("FeatureEnvy", "a.rb", 5)]
        expect(described_class.top_smell(smells).location.path.raw).to eq("a.rb")
      end
    end

    describe ".top_duplication" do
      let(:locs) do
        Set[build_location(path: build_path(raw: "a.rb"), line_start: 1),
            build_location(path: build_path(raw: "b.rb"), line_start: 1)]
      end

      it "breaks ties by signature ascending" do
        clusters = [build_duplication_cluster(signature: "zzz", locations: locs),
                    build_duplication_cluster(signature: "aaa", locations: locs)]
        expect(described_class.top_duplication(clusters).signature).to eq("aaa")
      end
    end

    describe ".top_complexity" do
      it "breaks ties by (path, line_start) ascending" do
        # Reverse-ordered: b.rb first.
        complexities = [hit_at("30.0", "b.rb", 1), hit_at("30.0", "a.rb", 5)]
        expect(described_class.top_complexity(complexities).location.path.raw).to eq("a.rb")
      end
    end
  end
end
