# frozen_string_literal: true

require "socket"

module RspackRails
  # Answers whether `rspack serve` is reachable. The result is cached briefly
  # so a page with several tags does not open a socket per tag.
  class DevServer
    CONNECT_TIMEOUT = 0.05

    def initialize(config, check_interval: 1.0)
      @config = config
      @check_interval = check_interval
      @checked_at = nil
      @running = false
    end

    def running?
      return false unless @config.dev_server_enabled

      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      return @running if @checked_at && now - @checked_at < @check_interval

      @checked_at = now
      @running = reachable?
    end

    # Same-origin path served by RspackRails::DevServerProxy.
    def url(path)
      "/rspack/#{path.to_s.delete_prefix("/")}"
    end

    private

    def reachable?
      Socket.tcp(@config.dev_server_host, @config.dev_server_port, connect_timeout: CONNECT_TIMEOUT) { true }
    rescue SystemCallError, SocketError, IOError
      false
    end
  end
end
