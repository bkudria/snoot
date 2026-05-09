# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"

# Spec source: snoot.allium -- contract AnalyserOrchestration
#              implementation: Snoot::AnalyserOrchestration::Default
RSpec.describe "AnalyserOrchestration::Default" do
  let(:adapter) { Snoot::AnalyserOrchestration::Default }

  describe "vendored_doc" do
    it "returns the reek-bundled doc for a known smell type", :aggregate_failures do
      doc = adapter.vendored_doc(build_smell_type(name: "FeatureEnvy"))
      expect(doc).to be_a(String)
      expect(doc).to include("Feature Envy")
    end

    it "returns nil for an unknown smell type" do
      expect(adapter.vendored_doc(build_smell_type(name: "DoesNotExist")))
        .to be_nil
    end
  end

  describe "reek_analyse" do
    let(:smelly_src) do
      <<~RUBY
        class Dirty
          def smelly(x)
            x.a + x.b + x.c + x.d
          end
        end
      RUBY
    end
    let(:smell_free_src) do
      <<~RUBY
        # A trivial, smell-free class for the empty-result test.
        class Tiny
        end
      RUBY
    end
    let(:undocumented_src) do
      <<~RUBY
        class Undocumented
        end
      RUBY
    end

    it "returns Snoot::Smell instances from a source containing a smell", :aggregate_failures do
      smells, path = analyse_reek(smelly_src)
      expect(smells).not_to be_empty
      expect(smells.first).to be_a(Snoot::Smell)
      expect(smells.first.location.path.raw).to eq(path)
      expect(smells.first.smell_type.name).to be_a(String)
    end

    it "returns an empty Set when no smells are detected" do
      expect(analyse_reek(smell_free_src).first).to eq(Set[])
    end

    it "prefixes the smell message with reek's context (e.g. class name)", :aggregate_failures do
      smells = analyse_reek(undocumented_src).first
      irresponsible = smells.find { |s| s.smell_type.name == "IrresponsibleModule" }
      expect(irresponsible).not_to be_nil
      expect(irresponsible&.message.to_s).to start_with("Undocumented ").and(include("has no descriptive comment"))
    end

    it "expands a directory Path to its .rb files (defers to Reek's SourceLocator)" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "dirty.rb"), smelly_src)
        smells = adapter.reek_analyse(Set[Snoot::Path.new(raw: dir)])
        expect(smells).not_to be_empty
      end
    end

    def seed_smelly_subdir(dir, sub)
      Dir.mkdir(File.join(dir, sub))
      File.write(File.join(dir, sub, "dirty.rb"), smelly_src)
    end

    def analyse_with_reek_yml(exclude:, smelly_under:)
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, ".reek.yml"), "exclude_paths:\n  - #{exclude}\n")
        smelly_under.each { |sub| seed_smelly_subdir(dir, sub) }
        smells = Dir.chdir(dir) { adapter.reek_analyse(Set[Snoot::Path.new(raw: ".")]) }
        return smells.map { |smell| smell.location.path.raw }
      end
    end

    it "honours .reek.yml exclude_paths discovered via cwd-ascent", :aggregate_failures do
      raw_paths = analyse_with_reek_yml(exclude: "skip", smelly_under: %w[skip keep])
      expect(raw_paths).not_to be_empty
      expect(raw_paths).to all(match(%r{(\A|/)keep/}))
    end
  end

  describe "flog_analyse" do
    let(:complex_src) do
      <<~RUBY
        class Tangled
          def gnarly(a, b, c)
            if a && b
              a.x + a.y + a.z
            elsif b || c
              b.p * c.q - a.r
            else
              [a, b, c].each { |v| v.zap.zip(v.zog) }
            end
          end
        end
      RUBY
    end
    let(:trivial_src) do
      <<~RUBY
        # No methods here -- flog has nothing to score.
        class Empty
        end
      RUBY
    end

    it "returns Snoot::ComplexityHit instances for a method with measurable score", :aggregate_failures do
      hits = analyse_flog(complex_src).first
      expect(hits).not_to be_empty
      expect(hits.first).to be_a(Snoot::ComplexityHit)
    end

    it "populates location, method_name (Class#method), and BigDecimal score", :aggregate_failures do
      hits, path = analyse_flog(complex_src)
      hit = hits.find { |h| h.method_name == "Tangled#gnarly" }
      expect(hit.location.path.raw).to eq(path)
      expect(hit.location.line_start).to eq(hit.location.line_end)
      expect(hit.score).to be_a(BigDecimal).and(be > 0)
    end

    it "returns an empty Set for a file with no methods" do
      expect(analyse_flog(trivial_src).first).to eq(Set[])
    end

    it "expands a directory Path to its .rb files (defers to PathExpander)" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "tangled.rb"), complex_src)
        hits = adapter.flog_analyse(Set[Snoot::Path.new(raw: dir)])
        expect(hits).not_to be_empty
      end
    end
  end

  describe "flay_analyse" do
    let(:duplicated_method) do
      <<~RUBY
        class %<klass>s
          def heavy(a, b, c, d, e)
            x = a + b + c
            y = d * e - a
            z = (x * y) / (a + 1)
            [x, y, z].each { |v| puts v.inspect }
            { x: x, y: y, z: z, sum: x + y + z }
          end
        end
      RUBY
    end
    let(:dup_pair) do
      [format(duplicated_method, klass: "Alpha"), format(duplicated_method, klass: "Beta")]
    end

    it "returns Snoot::DuplicationCluster instances when two files share a method body", :aggregate_failures do
      clusters, = analyse_flay(*dup_pair)
      expect(clusters).not_to be_empty
      expect(clusters.first).to be_a(Snoot::DuplicationCluster)
    end

    it "populates signature (non-empty String) and locations across both inputs", :aggregate_failures do
      clusters, p1, p2 = analyse_flay(*dup_pair)
      cluster = clusters.first
      expect(cluster.signature).not_to be_empty
      expect(cluster.locations.size).to be >= 2
      expect(cluster.locations.map { |l| l.path.raw }).to all(satisfy { |p| [p1, p2].include?(p) })
    end

    it "returns an empty Set when no duplication exceeds Flay's mass threshold" do
      src_a = "class Solo; def only; 1; end; end\n"
      src_b = "class Lone; def alone; 2; end; end\n"
      expect(analyse_flay(src_a, src_b).first).to eq(Set[])
    end

    it "expands a directory Path to its .rb files (defers to PathExpander)" do
      Dir.mktmpdir do |dir|
        dup_pair.each_with_index { |src, i| File.write(File.join(dir, "f#{i}.rb"), src) }
        expect(adapter.flay_analyse(Set[Snoot::Path.new(raw: dir)])).not_to be_empty
      end
    end
  end

  describe "significant_smells" do
    let(:envy) { build_smell(smell_type: build_smell_type(name: "FeatureEnvy")) }
    let(:tmm_pair) do
      Set[
        build_smell(smell_type: build_smell_type(name: "TooManyMethods"), location: build_location(line_start: 2)),
        build_smell(smell_type: build_smell_type(name: "TooManyMethods"), location: build_location(line_start: 3))
      ]
    end

    it "drops smell types whose instance count is below the floor" do
      result = adapter.significant_smells(Set[envy] | tmm_pair)
      expect(result.map { |smell| smell.smell_type.name }).to contain_exactly("TooManyMethods", "TooManyMethods")
    end

    it "returns an empty Set when every smell type is a singleton" do
      tmm = build_smell(smell_type: build_smell_type(name: "TooManyMethods"))
      expect(adapter.significant_smells(Set[envy, tmm])).to eq(Set[])
    end

    it "returns an empty Set for empty input" do
      expect(adapter.significant_smells(Set[])).to eq(Set[])
    end
  end

  describe "significant_complexities" do
    let(:hit_low)  { build_complexity_hit(score: BigDecimal("24.0"), method_name: "Foo#low") }
    let(:hit_at)   { build_complexity_hit(score: BigDecimal("25.0"), method_name: "Foo#at") }
    let(:hit_high) { build_complexity_hit(score: BigDecimal("50.0"), method_name: "Foo#high") }

    it "drops ComplexityHit instances scoring below the floor" do
      result = adapter.significant_complexities(Set[hit_low, hit_at, hit_high])
      expect(result.map(&:method_name)).to contain_exactly("Foo#at", "Foo#high")
    end

    it "returns an empty Set for empty input" do
      expect(adapter.significant_complexities(Set[])).to eq(Set[])
    end
  end

  describe "significant_duplications" do
    it "passes duplication clusters through unchanged" do
      cluster_a = build_duplication_cluster(signature: "a")
      cluster_b = build_duplication_cluster(signature: "b")
      input = Set[cluster_a, cluster_b]
      expect(adapter.significant_duplications(input)).to eq(input)
    end

    it "returns an empty Set for empty input" do
      expect(adapter.significant_duplications(Set[])).to eq(Set[])
    end
  end

  # FakeOrchestration is the test double for the AnalyserOrchestration contract.
  # Its significance methods are identity-by-default so that existing CLI tests
  # exercising outcome routing aren't reshaped by floor policy.
  describe "FakeOrchestration significance identity-by-default" do
    let(:fake) { fake_orchestration }

    it "passes smells through unchanged" do
      smells = Set[build_smell, build_smell(smell_type: build_smell_type(name: "Other"))]
      expect(fake.significant_smells(smells)).to eq(smells)
    end

    it "passes complexities through unchanged" do
      hits = Set[build_complexity_hit(score: BigDecimal("1.0"))]
      expect(fake.significant_complexities(hits)).to eq(hits)
    end

    it "passes duplications through unchanged" do
      clusters = Set[build_duplication_cluster]
      expect(fake.significant_duplications(clusters)).to eq(clusters)
    end
  end

  describe "FakeOrchestration analyse" do
    let(:smell) { build_smell }
    let(:complexity) { build_complexity_hit }
    let(:duplication) { build_duplication_cluster }
    let(:configured_fake) do
      fake_orchestration(smells: Set[smell], complexities: Set[complexity], duplications: Set[duplication])
    end

    it "returns a Sources bundling the configured analyser outputs" do
      expected = Snoot::Sources.new(smells: Set[smell], complexities: Set[complexity], duplications: Set[duplication])
      expect(configured_fake.analyse(Set[build_path])).to eq(expected)
    end

    it "returns AnalyserFailure(:reek) when reek_raises is set" do
      fake = fake_orchestration(reek_raises: StandardError.new("reek-boom"))
      expect(fake.analyse(Set[build_path]))
        .to be_a(Snoot::AnalyserFailure).and(have_attributes(analyser: :reek, message: "reek-boom"))
    end

    it "returns AnalyserFailure(:flog) when flog_raises is set" do
      fake = fake_orchestration(flog_raises: StandardError.new("flog-boom"))
      expect(fake.analyse(Set[build_path]).analyser).to eq(:flog)
    end

    it "returns AnalyserFailure(:flay) when flay_raises is set" do
      fake = fake_orchestration(flay_raises: StandardError.new("flay-boom"))
      expect(fake.analyse(Set[build_path]).analyser).to eq(:flay)
    end

    it "honours canonical order: when flog and flay both raise, returns :flog" do
      fake = fake_orchestration(
        flog_raises: StandardError.new("flog-first"),
        flay_raises: StandardError.new("flay-also")
      )
      expect(fake.analyse(Set[build_path]).analyser).to eq(:flog)
    end
  end

  describe "Default analyse" do
    let(:smell_free_src) do
      <<~RUBY
        # A trivial, smell-free class for the empty-result test.
        class Tiny
        end
      RUBY
    end
    let(:paths) { Set[build_path] }

    def with_temp_path(src)
      Tempfile.create(["good", ".rb"]) do |io|
        io.write(src)
        io.flush
        yield Snoot::Path.new(raw: io.path)
      end
    end

    def expected_sources_for(temp_paths)
      Snoot::Sources.new(
        smells: adapter.reek_analyse(temp_paths),
        complexities: adapter.flog_analyse(temp_paths),
        duplications: adapter.flay_analyse(temp_paths)
      )
    end

    it "returns a Sources bundling reek/flog/flay outputs on success" do
      with_temp_path(smell_free_src) do |path|
        temp_paths = Set[path]
        expect(adapter.analyse(temp_paths)).to eq(expected_sources_for(temp_paths))
      end
    end

    context "when reek raises" do
      before do
        allow(adapter).to receive(:reek_analyse).and_raise(StandardError.new("reek-boom"))
        allow(adapter).to receive(:flog_analyse).and_call_original
        allow(adapter).to receive(:flay_analyse).and_call_original
      end

      it "returns AnalyserFailure(:reek) and skips flog/flay", :aggregate_failures do
        result = adapter.analyse(paths)
        expect(result).to be_a(Snoot::AnalyserFailure).and(have_attributes(analyser: :reek, message: "reek-boom"))
        expect(adapter).not_to have_received(:flog_analyse)
        expect(adapter).not_to have_received(:flay_analyse)
      end
    end

    context "when flog raises" do
      before do
        allow(adapter).to receive(:reek_analyse).and_return(Set[])
        allow(adapter).to receive(:flog_analyse).and_raise(StandardError.new("flog-boom"))
        allow(adapter).to receive(:flay_analyse).and_call_original
      end

      it "returns AnalyserFailure(:flog) and skips flay", :aggregate_failures do
        result = adapter.analyse(paths)
        expect(result).to be_a(Snoot::AnalyserFailure).and(have_attributes(analyser: :flog, message: "flog-boom"))
        expect(adapter).not_to have_received(:flay_analyse)
      end
    end

    context "when flay raises" do
      before do
        allow(adapter).to receive_messages(reek_analyse: Set[], flog_analyse: Set[])
        allow(adapter).to receive(:flay_analyse).and_raise(StandardError.new("flay-boom"))
      end

      it "returns AnalyserFailure(:flay)" do
        expect(adapter.analyse(paths))
          .to be_a(Snoot::AnalyserFailure).and(have_attributes(analyser: :flay, message: "flay-boom"))
      end
    end
  end
end
