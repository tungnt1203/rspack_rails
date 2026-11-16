# frozen_string_literal: true

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

    module_function

    # config/rspack/rails.mjs for this version of the gem.
    def base_content
      File.read(TEMPLATE).gsub("__RSPACK_RAILS_VERSION__", VERSION)
    end

    # Whether rspack.config.mjs builds on config/rspack/rails.mjs. Configs
    # generated before 0.13.0 hold the whole config themselves.
    def managed?(root)
      app = Pathname(root).join(APP)
      app.file? && app.read.include?("config/rspack/rails.mjs")
    end

    def current?(root)
      base = Pathname(root).join(BASE)
      base.file? && base.read == base_content
    end

    # Writes config/rspack/rails.mjs when it is missing or from another version.
    # Returns true when it wrote the file.
    def sync(root)
      return false if current?(root)

      base = Pathname(root).join(BASE)
      base.dirname.mkpath
      base.write(base_content)
      true
    end
  end
end
