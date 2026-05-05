# frozen_string_literal: true

require "spec_helper"

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
end
