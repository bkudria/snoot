# frozen_string_literal: true

require_relative "lib/snoot/version"

Gem::Specification.new do |spec|
  spec.name        = "snoot"
  spec.version     = Snoot::VERSION
  spec.authors     = ["Benjamin Kudria"]
  spec.email       = ["ben@kudria.net"]

  spec.summary     = "Single-finding agent-targeted reek/flog/flay reporter."
  spec.description = <<~DESC
    snoot orchestrates reek, flog and flay over a configured path set
    and emits a single agent-targeted report describing one finding.
    Designed for an LLM coding agent as the reader.
  DESC
  spec.homepage    = "https://github.com/bkudria/snoot"
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 4.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "data/reek_docs/*.md",
    "data/reek_docs/LICENSE",
    "exe/snoot",
    "snoot.allium",
    "LICENSE",
    "README.md"
  ]
  spec.bindir        = "exe"
  spec.executables   = ["snoot"]
  spec.require_paths = ["lib"]

  spec.metadata["rubygems_mfa_required"] = "true"

  spec.add_dependency "bigdecimal", "~> 3.1"
  spec.add_dependency "flay", "~> 2.14"
  spec.add_dependency "flog", "~> 4.9"
  spec.add_dependency "reek", "~> 6.5"
end
