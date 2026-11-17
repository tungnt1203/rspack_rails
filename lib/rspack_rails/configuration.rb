# frozen_string_literal: true

module RspackRails
  # Settings shared by the dev server check and the view helpers.
  # Defaults come from the same environment variables rspack.config.mjs reads.
  class Configuration
    attr_reader :dev_server_host, :dev_server_port
    attr_writer :dev_server_enabled

    def initialize(env = ENV)
      @env = env
      @dev_server_host = env.fetch("RSPACK_DEV_SERVER_HOST", "localhost")
      @dev_server_port = Integer(env.fetch("RSPACK_DEV_SERVER_PORT", 3036))
      @dev_server_enabled = nil
    end

    # rspack serve reads only RSPACK_DEV_SERVER_HOST and _PORT, so a host or
    # port set here leaves Rails looking for a dev server where none listens.
    def dev_server_host=(host)
      deprecate_address("dev_server_host", "RSPACK_DEV_SERVER_HOST")
      @dev_server_host = host
    end

    def dev_server_port=(port)
      deprecate_address("dev_server_port", "RSPACK_DEV_SERVER_PORT")
      @dev_server_port = port
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

    private

    def deprecate_address(setting, variable)
      RspackRails.deprecator.warn(
        "RspackRails.config.#{setting}= is deprecated and will be removed in rspack_rails 1.0: rspack serve " \
        "does not read it. Set #{variable} instead, which both Rails and rspack read."
      )
    end
  end
end
