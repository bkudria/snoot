# frozen_string_literal: true

require "spec_helper"

# Source: RubyGems convention -- gem version constant
RSpec.describe "Snoot::VERSION" do
  it "is a SemVer string" do
    expect(Snoot::VERSION).to match(/\A\d+\.\d+\.\d+(\.\w+)?\z/)
  end
end
