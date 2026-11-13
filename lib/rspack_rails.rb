# frozen_string_literal: true

require_relative "rspack_rails/version"
require_relative "rspack_rails/package_manager"
require_relative "rspack_rails/configuration"
require_relative "rspack_rails/dev_server"
require_relative "rspack_rails/entrypoints"

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
  end
end

require_relative "rspack_rails/railtie" if defined?(Rails::Railtie)
