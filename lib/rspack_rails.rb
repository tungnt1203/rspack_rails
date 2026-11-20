# frozen_string_literal: true

require "active_support"
require "active_support/deprecation"
require_relative "rspack_rails/version"
require_relative "rspack_rails/package_manager"
require_relative "rspack_rails/configuration"
require_relative "rspack_rails/dev_server"
require_relative "rspack_rails/entrypoints"
require_relative "rspack_rails/manifest"

# Rspack integration for Rails: rake tasks, installer and view helpers.
module RspackRails
  class Error < StandardError; end

  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def dev_server
      @dev_server ||= DevServer.new(config)
    end

    # Internal. The dev server's manifest while it runs, the build's otherwise
    # (also under a config/rspack/rails.mjs from before 1.0.3, which writes
    # only that one). One of each per app root: new ones when Rails.root
    # changes (another app in the same process, as in tests or an engine's
    # dummy app).
    def manifest
      root = app_root
      unless @manifests&.first&.root == root
        @manifests = [Manifest.new(root), Manifest.new(root, Manifest::DEV_PATH)].freeze
      end
      build, dev = @manifests
      dev_server.running? && dev.path.file? ? dev : build
    end

    # Internal.
    def app_root
      Pathname(defined?(::Rails.root) && ::Rails.root ? ::Rails.root : Dir.pwd)
    end

    # Internal. Registered with Rails.application.deprecators, so the app's
    # config.active_support.deprecation applies once the app is initialized.
    # Before that (rake tasks that do not load :environment), warnings go to stderr.
    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("2.0", "rspack_rails")
    end
  end
end

require_relative "rspack_rails/railtie" if defined?(Rails::Railtie)
