# frozen_string_literal: true

require "spec_helper"
require_relative "../../../rakelib/release_prep"

RSpec.describe ReleasePrep::Changelog do
  let(:compare) { "https://github.com/o/r/compare" }
  let(:changelog) do
    <<~MD
      # Changelog

      ## [Unreleased]

      ### Fixed

      - A bug.

      ## [0.1.0] - 2026-05-14

      ### Added

      - Initial release.

      [Unreleased]: #{compare}/v0.1.0...HEAD
      [0.1.0]: https://github.com/o/r/releases/tag/v0.1.0
    MD
  end

  describe ".promote" do
    subject(:promoted) { described_class.promote(changelog, version: "0.2.0", date: "2026-10-29") }

    it "moves the Unreleased entries under a dated version heading" do
      expect(promoted).to include(<<~MD)
        ## [Unreleased]

        ## [0.2.0] - 2026-10-29

        ### Fixed

        - A bug.

        ## [0.1.0] - 2026-05-14
      MD
    end

    it "points Unreleased at the new tag and links the new version to its diff" do
      expect(promoted).to end_with(<<~MD)
        [Unreleased]: #{compare}/v0.2.0...HEAD
        [0.2.0]: #{compare}/v0.1.0...v0.2.0
        [0.1.0]: https://github.com/o/r/releases/tag/v0.1.0
      MD
    end

    it "refuses when Unreleased has no entries" do
      empty = changelog.sub("### Fixed\n\n- A bug.\n\n", "")
      expect { described_class.promote(empty, version: "0.2.0", date: "2026-10-29") }
        .to raise_error(ReleasePrep::Error, /Unreleased.*empty/)
    end

    it "refuses a version that already has a section" do
      expect { described_class.promote(changelog, version: "0.1.0", date: "2026-10-29") }
        .to raise_error(ReleasePrep::Error, /already has a 0\.1\.0 section/)
    end

    it "refuses a changelog without an Unreleased compare link" do
      unlinked = changelog.sub(/^\[Unreleased\]:.*\n/, "")
      expect { described_class.promote(unlinked, version: "0.2.0", date: "2026-10-29") }
        .to raise_error(ReleasePrep::Error, /link/)
    end
  end

  describe ".notes" do
    it "returns a version's entries without its heading" do
      expect(described_class.notes(changelog, "0.1.0")).to eq("### Added\n\n- Initial release.\n")
    end

    it "stops at the next version heading" do
      promoted = described_class.promote(changelog, version: "0.2.0", date: "2026-10-29")
      expect(described_class.notes(promoted, "0.2.0")).to eq("### Fixed\n\n- A bug.\n")
    end

    it "refuses a version with no section" do
      expect { described_class.notes(changelog, "9.9.9") }
        .to raise_error(ReleasePrep::Error, /9\.9\.9/)
    end
  end
end
