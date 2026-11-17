# frozen_string_literal: true

module RspackRails
  # Settings shared by the dev server check and the view helpers.
  # The host and port come from the same environment variables rspack serve
  # reads (RSPACK_DEV_SERVER_HOST, RSPACK_DEV_SERVER_PORT), so they cannot be
  # set here: Rails would look for a dev server where none listens.
  class Configuration
    attr_reader :dev_server_host, :dev_server_port
    attr_writer :dev_server_enabled

    def initialize(env = ENV)
      @env = env
      @dev_server_host = env.fetch("RSPACK_DEV_SERVER_HOST", "localhost")
      @dev_server_port = Integer(env.fetch("RSPACK_DEV_SERVER_PORT", 3036))
      @dev_server_enabled = nil
    end

    # Unless set explicitly, the dev server is used only in development and
    # can be switched off with RSPACK_DEV_SERVER=false.
    def dev_server_enabled
      return @dev_server_enabled unless @dev_server_enabled.nil?

      return false if @env["RSPACK_DEV_SERVER"] == "false"

      defined?(::Rails.env) ? ::Rails.env.development? : false
    end

    def dev_server_url
      "http://#{dev_server_host}:#{dev_server_port}"
    end
  end
end
