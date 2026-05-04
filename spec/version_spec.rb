# frozen_string_literal: true

require "spec_helper"

# Spec source: slice 11 -- gem version constant
RSpec.describe "Snoot::VERSION" do
  it "is a SemVer string" do
    expect(Snoot::VERSION).to match(/\A\d+\.\d+\.\d+(\.\w+)?\z/)
  end
end
