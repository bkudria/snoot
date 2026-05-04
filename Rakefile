require "bundler/gem_tasks"
require "fileutils"
require "shellwords"
require "tmpdir"

DOCS_TARGET = File.expand_path("data/reek_docs", __dir__).freeze

def bundled_reek_version
  require "bundler/setup"
  Gem.loaded_specs.fetch("reek").version.to_s
end

def fetch_reek_docs(version, target)
  url = "https://github.com/troessner/reek/archive/refs/tags/v#{version}.tar.gz"
  Dir.mktmpdir do |tmp|
    return false unless system("curl -fsSL #{url.shellescape} | tar -xz -C #{tmp.shellescape}")

    src = File.join(tmp, "reek-#{version}")
    Dir.glob(File.join(src, "docs", "*.md")).each { |md| FileUtils.cp(md, target) }
    license = File.join(src, "License.txt")
    FileUtils.cp(license, File.join(target, "LICENSE")) if File.exist?(license)
  end
  true
end

namespace :docs do
  desc "Sync reek's vendored markdown docs and license into data/reek_docs/ (pinned to bundled reek version)"
  task :sync do
    version = bundled_reek_version
    FileUtils.rm_rf(DOCS_TARGET)
    FileUtils.mkdir_p(DOCS_TARGET)
    puts "Fetching reek v#{version} docs..."
    raise "docs:sync failed" unless fetch_reek_docs(version, DOCS_TARGET)

    count = Dir.glob(File.join(DOCS_TARGET, "*.md")).size
    license = File.exist?(File.join(DOCS_TARGET, "LICENSE")) ? "+LICENSE" : "(no LICENSE!)"
    puts "Synced #{count} markdown files #{license} into #{DOCS_TARGET}"
  end
end
