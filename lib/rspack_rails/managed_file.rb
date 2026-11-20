# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require_relative "version"

module RspackRails
  # A file rspack_rails writes into an app and rewrites for each version of
  # the gem: config/rspack/rails.mjs, and the Stimulus and React loaders once
  # their installers have run. Each carries a checksum of its own content, so
  # a hand edit can be told from a file written by another version; hand
  # edits are saved to tmp/rspack_rails/ before the file is replaced.
  class ManagedFile
    VERSION_PLACEHOLDER = "__RSPACK_RAILS_VERSION__"
    CHECKSUM_PLACEHOLDER = "__RSPACK_RAILS_CHECKSUM__"
    CHECKSUM_LINE = %r{^// Checksum: (\S+)}
    BACKUP_DIR = "tmp/rspack_rails"
    INSTALL = File.expand_path("../install", __dir__)

    # file: the ManagedFile. written: whether sync rewrote it. backup: where
    # the hand edits it replaced were saved, or nil.
    SyncResult = Data.define(:file, :written, :backup) do
      def path
        file.path
      end

      # What to tell the app when hand edits were replaced, or nil.
      def edits_message
        file.edits_message(backup) if backup
      end
    end

    attr_reader :path

    # required: written even when the app does not have it yet.
    def initialize(path, template:, required: false, customize: nil)
      @path = path
      @template = template
      @required = required
      @customize = customize
    end

    BASE = new("config/rspack/rails.mjs", template: File.join(INSTALL, "rails.mjs"), required: true,
                                          customize: "in the railsConfig callback of rspack.config.mjs")
    STIMULUS = new("app/javascript/controllers/autoload.js",
                   template: File.join(INSTALL, "stimulus/autoload.js"))
    REACT = new("app/javascript/components/mount.js",
                template: File.join(INSTALL, "react/mount.js"))
    ALL = [BASE, STIMULUS, REACT].freeze

    # Syncs every managed file the app has, and config/rspack/rails.mjs unless
    # `base` is false (rspack.config.mjs does not build on it). Returns what was written.
    def self.sync_all(root, base: true)
      (base ? ALL : ALL - [BASE]).map { |file| file.sync(root) }.select(&:written)
    end

    def self.checksum(content)
      Digest::SHA256.hexdigest(normalize(content).sub(CHECKSUM_LINE, "// Checksum: #{CHECKSUM_PLACEHOLDER}"))[0, 16]
    end

    # Line endings do not count: Git checks files out with CRLF on Windows
    # (core.autocrlf), which is not a hand edit.
    def self.normalize(content)
      content.gsub("\r\n", "\n")
    end

    # The file for this version of the gem, carrying a checksum of its own content.
    def content
      content = File.read(@template).gsub(VERSION_PLACEHOLDER, VERSION)
      content.sub(CHECKSUM_PLACEHOLDER, self.class.checksum(content))
    end

    def exist?(root)
      Pathname(root).join(path).file?
    end

    def current?(root)
      exist?(root) && read(root) == content
    end

    # Whether the file was changed by hand since rspack_rails wrote it. A file
    # without a checksum (from before 0.18, or written by hand) counts as
    # edited, so it is saved before it is replaced.
    def edited?(root)
      return false unless exist?(root)

      existing = read(root)
      stored = existing[CHECKSUM_LINE, 1]
      stored.nil? || stored != self.class.checksum(existing)
    end

    # :missing, :edited (by hand), :outdated (another version) or :current.
    def state(root)
      return :missing unless exist?(root)
      return :edited if edited?(root)

      current?(root) ? :current : :outdated
    end

    # Writes the file when it is from another version or edited by hand, and
    # when it is missing if it is required or `create` is set (its installer
    # is running). Hand edits are copied to tmp/rspack_rails/ first.
    def sync(root, create: false)
      return SyncResult.new(file: self, written: false, backup: nil) unless due?(root, create)

      backup = back_up(root) if edited?(root)
      file = Pathname(root).join(path)
      file.dirname.mkpath
      file.write(content)
      SyncResult.new(file: self, written: true, backup: backup)
    end

    def edits_message(backup)
      how = @customize || "in a file of your own: copy #{path} to it, import that instead and delete #{path}"
      "#{path} had hand edits, which rspack_rails replaced (saved to #{backup}). Make changes #{how}; " \
        "rspack_rails rewrites #{path} on upgrades."
    end

    private

    def read(root)
      self.class.normalize(Pathname(root).join(path).read)
    end

    def due?(root, create)
      return !current?(root) if exist?(root)

      @required || create
    end

    def back_up(root)
      name = "#{File.basename(path, ".*")}-#{Time.now.strftime("%Y%m%d%H%M%S")}#{File.extname(path)}"
      backup = Pathname(root).join(BACKUP_DIR, name)
      backup.dirname.mkpath
      FileUtils.cp(Pathname(root).join(path), backup)
      backup.relative_path_from(Pathname(root))
    end
  end
end
