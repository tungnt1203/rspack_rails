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

    def manifest
      @manifest ||= Manifest.new(defined?(::Rails.root) && ::Rails.root ? ::Rails.root : Dir.pwd)
    end

    # Registered with Rails.application.deprecators, so the app's
    # config.active_support.deprecation applies.
    def deprecator
      @deprecator ||= ActiveSupport::Deprecation.new("1.0", "rspack_rails")
    end

    # ENV[name], or ENV[old] (the variable's name before 1.0) with a deprecation warning.
    def env_var(name, old, env = ENV)
      return env[name] if env.key?(name) || !env.key?(old)

      deprecator.warn("#{old} is deprecated and will be removed in rspack_rails 1.0. Set #{name} instead.")
      env[old]
    end
  end
end

require_relative "rspack_rails/railtie" if defined?(Rails::Railtie)
