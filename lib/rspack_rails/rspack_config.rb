# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require_relative "version"

module RspackRails
  # The two config files in an app: rspack.config.mjs, the app's own, and
  # config/rspack/rails.mjs, the defaults it imports. The gem owns the second
  # one and rewrites it for each version, so upgrading never asks the app to
  # merge config changes by hand.
  module RspackConfig
    APP = "rspack.config.mjs"
    BASE = "config/rspack/rails.mjs"
    TEMPLATE = File.expand_path("../install/rails.mjs", __dir__)
    CHECKSUM_PLACEHOLDER = "__RSPACK_RAILS_CHECKSUM__"
    CHECKSUM_LINE = %r{^// Checksum: (\S+)}
    BACKUP_DIR = "tmp/rspack_rails"

    # written: whether sync rewrote the file. backup: where the hand edits it
    # replaced were saved, or nil.
    SyncResult = Data.define(:written, :backup)

    module_function

    # config/rspack/rails.mjs for this version of the gem, carrying a checksum
    # of its own content.
    def base_content
      content = File.read(TEMPLATE).gsub("__RSPACK_RAILS_VERSION__", VERSION)
      content.sub(CHECKSUM_PLACEHOLDER, checksum(content))
    end

    def checksum(content)
      Digest::SHA256.hexdigest(content.sub(CHECKSUM_LINE, "// Checksum: #{CHECKSUM_PLACEHOLDER}"))[0, 16]
    end

    # Whether config/rspack/rails.mjs was changed by hand since rspack_rails
    # wrote it. Files from before 0.17.0 carry no checksum and count as unedited.
    def edited?(root)
      base = Pathname(root).join(BASE)
      return false unless base.file?

      content = base.read
      stored = content[CHECKSUM_LINE, 1]
      !stored.nil? && stored != checksum(content)
    end

    # Whether rspack.config.mjs builds on config/rspack/rails.mjs. Configs
    # generated before 0.13.0 hold the whole config themselves.
    def managed?(root)
      app = Pathname(root).join(APP)
      app.file? && app.read.include?("config/rspack/rails.mjs")
    end

    # :missing, :edited (by hand), :outdated (another version) or :current.
    def state(root)
      return :missing unless Pathname(root).join(BASE).file?
      return :edited if edited?(root)

      current?(root) ? :current : :outdated
    end

    def current?(root)
      base = Pathname(root).join(BASE)
      base.file? && base.read == base_content
    end

    # Writes config/rspack/rails.mjs when it is missing, from another version
    # or edited by hand. Hand edits are copied to tmp/rspack_rails/ first.
    def sync(root)
      return SyncResult.new(written: false, backup: nil) if current?(root)

      backup = back_up_edits(root) if edited?(root)
      base = Pathname(root).join(BASE)
      base.dirname.mkpath
      base.write(base_content)
      SyncResult.new(written: true, backup: backup)
    end

    def back_up_edits(root)
      backup = Pathname(root).join(BACKUP_DIR, "rails-#{Time.now.strftime("%Y%m%d%H%M%S")}.mjs")
      backup.dirname.mkpath
      FileUtils.cp(Pathname(root).join(BASE), backup)
      backup.relative_path_from(Pathname(root))
    end

    def edits_message(backup)
      "#{BASE} had hand edits, which rspack_rails replaced (saved to #{backup}). Make changes in the " \
        "railsConfig callback of #{APP} instead; rspack_rails rewrites #{BASE} on upgrades."
    end
  end
end
