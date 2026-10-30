# frozen_string_literal: true

require "open3"

module ReleasePrep
  class Error < StandardError; end

  # Turns the Unreleased changelog entries into a tagged release commit on
  # main, leaving the push to the maintainer.
  class Run
    VERSION_FILE = "lib/snoot/version.rb"
    CHANGELOG = "CHANGELOG.md"
    LOCKFILE = "Gemfile.lock"
    GEM_NAME = "snoot"
    RELEASE_BRANCH = "main"

    def initialize(root:, input:, output:, today:)
      @root = root
      @input = input
      @output = output
      @today = today
    end

    def call(requested_version)
      ensure_releasable
      current = VersionFile.current(read(VERSION_FILE))
      version = requested_version || ask_for_version(current)
      validate(version, current)
      write_release(version)
      @output.puts "Released v#{version} locally. Publish with: git push origin #{RELEASE_BRANCH} v#{version}"
    end

    private

    def ensure_releasable
      branch = git("branch", "--show-current").strip
      raise Error, "releases are cut from #{RELEASE_BRANCH}, not #{branch}" unless branch == RELEASE_BRANCH
      raise Error, "the working tree has uncommitted changes" unless git("status", "--porcelain").empty?
    end

    def ask_for_version(current)
      messages = commit_messages_since_last_tag
      suggestion = NextVersion.suggest(current: current, commit_messages: messages)
      @output.puts "Commits since the last release:"
      messages.each { |message| @output.puts "  #{message.lines.first.strip}" }
      @output.print "Next version [#{suggestion}]: "
      answer = @input.gets.to_s.strip
      answer.empty? ? suggestion : answer
    end

    def commit_messages_since_last_tag
      last_tag = git("describe", "--tags", "--abbrev=0", "--match", "v*").strip
      git("log", "--format=%B%x00", "#{last_tag}..HEAD").split("\0").map(&:strip).reject(&:empty?)
    end

    def validate(version, current)
      raise Error, "#{version.inspect} is not an X.Y.Z version" unless version.match?(/\A\d+\.\d+\.\d+\z/)
      return if Gem::Version.new(version) > Gem::Version.new(current)

      raise Error, "#{version} is not above the current version #{current}"
    end

    def write_release(version)
      File.write(path(CHANGELOG), Changelog.promote(read(CHANGELOG), version: version, date: @today.iso8601))
      File.write(path(VERSION_FILE), VersionFile.bump(read(VERSION_FILE), version))
      File.write(path(LOCKFILE), Lockfile.bump(read(LOCKFILE), gem: GEM_NAME, version: version))
      git("add", CHANGELOG, VERSION_FILE, LOCKFILE)
      git("commit", "-q", "-m", "chore(release): v#{version}")
      git("tag", "-m", "Version #{version}", "v#{version}")
    end

    def git(*args)
      out, status = Open3.capture2e("git", *args, chdir: @root)
      raise Error, "git #{args.first} failed: #{out.strip}" unless status.success?

      out
    end

    def path(relative) = File.join(@root, relative)
    def read(relative) = File.read(path(relative))
  end

  # Reads and rewrites the `VERSION = "x.y.z"` assignment in lib/snoot/version.rb.
  module VersionFile
    ASSIGNMENT = /(?<prefix>VERSION = ")(?<version>[^"]+)"/

    module_function

    def current(source)
      match = source.match(ASSIGNMENT) or raise Error, "no VERSION constant found"
      match[:version]
    end

    def bump(source, version)
      current(source)
      source.sub(ASSIGNMENT) { %(#{Regexp.last_match[:prefix]}#{version}") }
    end
  end

  # CI installs gems in frozen mode, which rejects a lockfile whose entry for
  # the gem itself disagrees with VERSION.
  module Lockfile
    module_function

    def bump(text, gem:, version:)
      entry = /^(?<indent> +)#{Regexp.escape(gem)} \([^)]+\)$/
      raise Error, "no lockfile entry for #{gem}" unless text.match?(entry)

      text.gsub(entry) { "#{Regexp.last_match[:indent]}#{gem} (#{version})" }
    end
  end

  # Edits a Keep a Changelog file whose footer links each heading to a GitHub
  # compare or tag URL.
  module Changelog
    UNRELEASED_HEADING = "## [Unreleased]\n"
    UNRELEASED_LINK = %r{^\[Unreleased\]: (?<compare>\S+/compare/)(?<previous>\S+)\.\.\.HEAD$}

    module_function

    def promote(text, version:, date:)
      raise Error, "CHANGELOG already has a #{version} section" if text.match?(/^## \[#{Regexp.escape(version)}\]/)
      raise Error, "the Unreleased section is empty" if section(text, "Unreleased").strip.empty?

      link = text.match(UNRELEASED_LINK) or raise Error, "no [Unreleased] compare link in CHANGELOG"
      text.sub(UNRELEASED_HEADING, "#{UNRELEASED_HEADING}\n## [#{version}] - #{date}\n")
          .sub(link[0], <<~LINKS.chomp)
            [Unreleased]: #{link[:compare]}v#{version}...HEAD
            [#{version}]: #{link[:compare]}#{link[:previous]}...v#{version}
          LINKS
    end

    def notes(text, version)
      "#{section(text, version).strip}\n"
    end

    def section(text, name)
      match = text.match(/^## \[#{Regexp.escape(name)}\][^\n]*\n(?<body>.*?)(?=^## \[|^\[[^\]]+\]: |\z)/m)
      raise Error, "CHANGELOG has no #{name} section" unless match

      match[:body]
    end
  end

  # Below 1.0.0 a breaking change bumps minor, since SemVer leaves 0.x free to break.
  module NextVersion
    SUBJECT = /\A(?<type>\w+)(?:\([^)]*\))?(?<breaking>!)?:/
    BREAKING_FOOTER = /^BREAKING[ -]CHANGE:/

    module_function

    def suggest(current:, commit_messages:)
      raise Error, "no commits since the last release" if commit_messages.empty?

      major, minor, patch = current.split(".").map(&:to_i)
      case bump_for(commit_messages, pre_one: major.zero?)
      when :major then "#{major + 1}.0.0"
      when :minor then "#{major}.#{minor + 1}.0"
      else "#{major}.#{minor}.#{patch + 1}"
      end
    end

    def bump_for(messages, pre_one:)
      return (pre_one ? :minor : :major) if messages.any? { |message| breaking?(message) }
      return :minor if messages.any? { |message| message[SUBJECT, :type] == "feat" }

      :patch
    end

    def breaking?(message)
      message.match(SUBJECT)&.[](:breaking) || message.match?(BREAKING_FOOTER)
    end
  end
end
