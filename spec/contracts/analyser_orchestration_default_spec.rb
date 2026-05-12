# frozen_string_literal: true

require "spec_helper"
require "tempfile"
require "tmpdir"

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

  describe "Reek path through analyse" do
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
        smells = adapter.analyse(Set[Snoot::Path.new(raw: dir)]).smells
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
        smells = Dir.chdir(dir) { adapter.analyse(Set[Snoot::Path.new(raw: ".")]).smells }
        return smells.map { |smell| smell.location.path.raw }
      end
    end

    it "honours .reek.yml exclude_paths discovered via cwd-ascent", :aggregate_failures do
      raw_paths = analyse_with_reek_yml(exclude: "skip", smelly_under: %w[skip keep])
      expect(raw_paths).not_to be_empty
      expect(raw_paths).to all(match(%r{(\A|/)keep/}))
    end
  end

  describe "Flog path through analyse" do
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

    it "expands a directory Path to its .rb/.rake files (defers to PathExpander, matches Flog::CLI)" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "tangled.rb"), complex_src)
        hits = adapter.analyse(Set[Snoot::Path.new(raw: dir)]).complexities
        expect(hits).not_to be_empty
      end
    end
  end

  describe "Flay path through analyse" do
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
        expect(adapter.analyse(Set[Snoot::Path.new(raw: dir)]).duplications).not_to be_empty
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

    it "returns a Sources of three empty Sets on smell-free input" do
      with_temp_path(smell_free_src) do |path|
        expect(adapter.analyse(Set[path]))
          .to eq(Snoot::Sources.new(smells: Set[], complexities: Set[], duplications: Set[]))
      end
    end

    context "when reek raises" do
      before do
        allow(Reek::Source::SourceLocator).to receive(:new).and_raise(StandardError.new("reek-boom"))
        allow(Flog).to receive(:new).and_call_original
        allow(Flay).to receive(:new).and_call_original
      end

      it "returns AnalyserFailure(:reek) and skips flog/flay", :aggregate_failures do
        result = adapter.analyse(paths)
        expect(result).to have_attributes(analyser: :reek, message: "reek-boom")
        expect(Flog).not_to have_received(:new)
        expect(Flay).not_to have_received(:new)
      end
    end

    context "when flog raises" do
      let(:fake_flog) { instance_double(Flog, flog: nil) }

      before do
        allow(fake_flog).to receive(:flog).and_raise(StandardError.new("flog-boom"))
        allow(Flog).to receive(:new).and_return(fake_flog)
        allow(Flay).to receive(:new).and_call_original
      end

      it "returns AnalyserFailure(:flog) and skips flay", :aggregate_failures do
        result = adapter.analyse(paths)
        expect(result).to have_attributes(analyser: :flog, message: "flog-boom")
        expect(Flay).not_to have_received(:new)
      end
    end

    context "when flay raises" do
      let(:fake_flay) { instance_double(Flay, process: nil) }

      before do
        allow(fake_flay).to receive(:process).and_raise(StandardError.new("flay-boom"))
        allow(Flay).to receive(:new).and_return(fake_flay)
      end

      it "returns AnalyserFailure(:flay)" do
        expect(adapter.analyse(paths)).to have_attributes(analyser: :flay, message: "flay-boom")
      end
    end
  end
end
