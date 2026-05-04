require "fileutils"
require "shellwords"

DOCS_TARGET = File.expand_path("data/reek_docs", __dir__).freeze

def bundled_reek_version
  require "bundler/setup"
  Gem.loaded_specs.fetch("reek").version.to_s
end

def fetch_reek_docs(version, target)
  url = "https://github.com/troessner/reek/archive/refs/tags/v#{version}.tar.gz"
  cmd = "curl -fsSL #{url.shellescape} | " \
        "tar -xz --strip-components=2 -C #{target.shellescape} reek-#{version}/docs"
  return false unless system(cmd)

  Dir.glob(File.join(target, "*")).each do |entry|
    FileUtils.rm_rf(entry) unless File.file?(entry) && entry.end_with?(".md")
  end
  true
end

namespace :docs do
  desc "Sync reek's vendored markdown docs into data/reek_docs/ (pinned to bundled reek version)"
  task :sync do
    version = bundled_reek_version
    FileUtils.rm_rf(DOCS_TARGET)
    FileUtils.mkdir_p(DOCS_TARGET)
    puts "Fetching reek v#{version} docs..."
    raise "docs:sync failed" unless fetch_reek_docs(version, DOCS_TARGET)

    count = Dir.glob(File.join(DOCS_TARGET, "*.md")).size
    puts "Synced #{count} markdown files into #{DOCS_TARGET}"
  end
end
