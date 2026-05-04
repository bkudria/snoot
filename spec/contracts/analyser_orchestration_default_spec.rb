require "spec_helper"

# Spec source: snoot.allium -- contract AnalyserOrchestration
#              implementation: Snoot::AnalyserOrchestration::Default
RSpec.describe "AnalyserOrchestration::Default" do
  let(:adapter) { Snoot::AnalyserOrchestration::Default.new }
  let(:smelly_src) do
    <<~RUBY
      class Dirty
        def smelly(x)
          x.a + x.b + x.c + x.d
        end
      end
    RUBY
  end

  describe "describe_location" do
    it "renders 'path:line_start-line_end'" do
      loc = build_location(path: build_path(raw: "lib/x.rb"),
                           line_start: 10, line_end: 20)
      expect(adapter.describe_location(loc)).to eq("lib/x.rb:10-20")
    end
  end

  describe "vendored_doc" do
    it "returns the reek-bundled doc for a known smell type" do
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
    it "returns Snoot::Smell instances from a source containing a smell" do
      with_ruby_tempfile(smelly_src) do |path|
        smells = adapter.reek_analyse(Set[Snoot::Path.new(raw: path)])
        expect(smells).not_to be_empty
        first = smells.first
        expect(first).to be_a(Snoot::Smell)
        expect(first.location.path.raw).to eq(path)
        expect(first.smell_type.name).to be_a(String)
      end
    end

    it "returns an empty Set when no smells are detected" do
      src = <<~RUBY
        # A trivial, smell-free class for the empty-result test.
        class Tiny
        end
      RUBY
      with_ruby_tempfile(src) do |path|
        result = adapter.reek_analyse(Set[Snoot::Path.new(raw: path)])
        expect(result).to eq(Set[])
      end
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

    it "returns Snoot::ComplexityHit instances for a method with measurable score" do
      with_ruby_tempfile(complex_src) do |path|
        hits = adapter.flog_analyse(Set[Snoot::Path.new(raw: path)])
        expect(hits).not_to be_empty
        first = hits.first
        expect(first).to be_a(Snoot::ComplexityHit)
      end
    end

    it "populates location, method_name (Class#method), and BigDecimal score" do
      with_ruby_tempfile(complex_src) do |path|
        hit = adapter.flog_analyse(Set[Snoot::Path.new(raw: path)])
                     .find { |h| h.method_name == "Tangled#gnarly" }
        expect(hit).not_to be_nil
        expect(hit.location.path.raw).to eq(path)
        expect(hit.location.line_start).to eq(hit.location.line_end)
        expect(hit.score).to be_a(BigDecimal)
        expect(hit.score).to be > 0
      end
    end

    it "returns an empty Set for a file with no methods" do
      src = <<~RUBY
        # No methods here -- flog has nothing to score.
        class Empty
        end
      RUBY
      with_ruby_tempfile(src) do |path|
        result = adapter.flog_analyse(Set[Snoot::Path.new(raw: path)])
        expect(result).to eq(Set[])
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

    it "returns Snoot::DuplicationCluster instances when two files share a method body" do
      with_ruby_tempfile(format(duplicated_method, klass: "Alpha")) do |p1|
        with_ruby_tempfile(format(duplicated_method, klass: "Beta")) do |p2|
          clusters = adapter.flay_analyse(
            Set[Snoot::Path.new(raw: p1), Snoot::Path.new(raw: p2)]
          )
          expect(clusters).not_to be_empty
          expect(clusters.first).to be_a(Snoot::DuplicationCluster)
        end
      end
    end

    it "populates signature (non-empty String) and locations across both inputs" do
      with_ruby_tempfile(format(duplicated_method, klass: "Alpha")) do |p1|
        with_ruby_tempfile(format(duplicated_method, klass: "Beta")) do |p2|
          cluster = adapter.flay_analyse(
            Set[Snoot::Path.new(raw: p1), Snoot::Path.new(raw: p2)]
          ).first
          expect(cluster.signature).to be_a(String)
          expect(cluster.signature).not_to be_empty
          expect(cluster.locations.size).to be >= 2
          expect(cluster.locations.map { |l| l.path.raw }).to all(satisfy { |p| [p1, p2].include?(p) })
        end
      end
    end

    it "returns an empty Set when no duplication exceeds Flay's mass threshold" do
      src_a = "class Solo; def only; 1; end; end\n"
      src_b = "class Lone; def alone; 2; end; end\n"
      with_ruby_tempfile(src_a) do |p1|
        with_ruby_tempfile(src_b) do |p2|
          result = adapter.flay_analyse(
            Set[Snoot::Path.new(raw: p1), Snoot::Path.new(raw: p2)]
          )
          expect(result).to eq(Set[])
        end
      end
    end
  end
end
