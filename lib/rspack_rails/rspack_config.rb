# frozen_string_literal: true

require "pathname"
require_relative "managed_file"

module RspackRails
  # The two config files in an app: rspack.config.mjs, the app's own, and
  # config/rspack/rails.mjs, the defaults it imports. The gem owns the second
  # one (ManagedFile::BASE) and rewrites it for each version, so upgrading
  # never asks the app to merge config changes by hand.
  module RspackConfig
    APP = "rspack.config.mjs"
    BASE = ManagedFile::BASE.path

    SyncResult = ManagedFile::SyncResult

    module_function

    # config/rspack/rails.mjs for this version of the gem, carrying a checksum
    # of its own content.
    def base_content
      ManagedFile::BASE.content
    end

    def checksum(content)
      ManagedFile.checksum(content)
    end

    # Whether config/rspack/rails.mjs was changed by hand since rspack_rails
    # wrote it. Files from before 0.17.0 carry no checksum and count as unedited.
    def edited?(root)
      ManagedFile::BASE.edited?(root)
    end

    # Whether rspack.config.mjs builds on config/rspack/rails.mjs. Configs
    # generated before 0.13.0 hold the whole config themselves.
    def managed?(root)
      app = Pathname(root).join(APP)
      app.file? && app.read.include?(BASE)
    end

    # :missing, :edited (by hand), :outdated (another version) or :current.
    def state(root)
      ManagedFile::BASE.state(root)
    end

    def current?(root)
      ManagedFile::BASE.current?(root)
    end

    # Writes config/rspack/rails.mjs when it is missing, from another version
    # or edited by hand. Hand edits are copied to tmp/rspack_rails/ first.
    def sync(root)
      ManagedFile::BASE.sync(root)
    end

    def edits_message(backup)
      ManagedFile::BASE.edits_message(backup)
    end
  end
end
