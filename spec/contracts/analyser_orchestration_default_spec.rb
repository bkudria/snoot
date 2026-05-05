# frozen_string_literal: true

require "spec_helper"

# Spec source: snoot.allium -- contract AnalyserOrchestration
#              implementation: Snoot::AnalyserOrchestration::Default
RSpec.describe "AnalyserOrchestration::Default" do
  let(:adapter) { Snoot::AnalyserOrchestration::Default.new }

  describe "describe_location" do
    it "renders 'path:line_start-line_end'" do
      loc = build_location(path: build_path(raw: "lib/x.rb"),
                           line_start: 10, line_end: 20)
      expect(adapter.describe_location(loc)).to eq("lib/x.rb:10-20")
    end
  end

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
end
