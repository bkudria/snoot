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

  describe "stubbed analysers (slice 10B)" do
    # These stubs let the adapter run end-to-end through AnalyseRun while
    # only Reek is implemented. Slice 10B replaces the empty-Set return
    # with real Flog/Flay output and updates these tests accordingly.
    it "returns an empty Set from flog_analyse until slice 10B" do
      expect(adapter.flog_analyse(Set[])).to eq(Set[])
    end

    it "returns an empty Set from flay_analyse until slice 10B" do
      expect(adapter.flay_analyse(Set[])).to eq(Set[])
    end
  end
end
