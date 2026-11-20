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
    # Said by the installers, the rake tasks and the doctor when APP does not
    # build on BASE; each adds what the reader should do next.
    NOT_MANAGED = "#{APP} does not build on #{BASE}".freeze
    REINSTALL = "Re-run `bin/rails rspack:install` and accept the new #{APP}".freeze

    module_function

    # Whether rspack.config.mjs builds on config/rspack/rails.mjs.
    def managed?(root)
      app = Pathname(root).join(APP)
      app.file? && app.read.include?(BASE)
    end
  end
end
