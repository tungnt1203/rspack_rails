# frozen_string_literal: true

require "net/http"
require "uri"

module RspackRails
  # Serves `rspack serve` output through the Rails app under /rspack/, so
  # scripts, chunks, workers and hot updates are same-origin with the page.
  # Browsers refuse to start a Web Worker from another origin, which is what
  # loading straight from localhost:3036 would be. The HMR websocket and lazy
  # compilation requests still go to the dev server directly.
  class DevServerProxy
    PREFIX = "/rspack/"
    # Response headers that describe the dev server connection, not the body.
    SKIPPED_HEADERS = %w[connection keep-alive transfer-encoding upgrade proxy-connection te trailer
                         content-length content-encoding].freeze
    FORWARDED_HEADERS = { "HTTP_IF_NONE_MATCH" => "If-None-Match", "HTTP_ACCEPT" => "Accept" }.freeze

    def initialize(app, config: RspackRails.config)
      @app = app
      @config = config
    end

    def call(env)
      return @app.call(env) unless proxied?(env)

      proxy(env)
    rescue SystemCallError, SocketError, IOError, Net::OpenTimeout, Net::ReadTimeout
      [502, { "content-type" => "text/plain" }, ["rspack dev server is not reachable at #{@config.dev_server_url}"]]
    end

    private

    def proxied?(env)
      env["PATH_INFO"].to_s.start_with?(PREFIX) &&
        %w[GET HEAD].include?(env["REQUEST_METHOD"]) &&
        @config.dev_server_enabled
    end

    def proxy(env)
      # A request made while rspack is compiling waits for the build to finish.
      response = Net::HTTP.start(@config.dev_server_host, @config.dev_server_port,
                                 open_timeout: 1, read_timeout: 120) { |http| http.request(build_request(env)) }

      headers = response.each_header.to_h.except(*SKIPPED_HEADERS)
      [response.code.to_i, headers, [response.body.to_s]]
    end

    # /rspack/application.js -> /application.js: the dev server serves from
    # its root, which also covers configs generated before the proxy existed.
    def build_request(env)
      path = env["PATH_INFO"].delete_prefix(PREFIX.chomp("/"))
      path = "#{path}?#{env["QUERY_STRING"]}" unless env["QUERY_STRING"].to_s.empty?
      request = (env["REQUEST_METHOD"] == "HEAD" ? Net::HTTP::Head : Net::HTTP::Get).new(path)
      FORWARDED_HEADERS.each { |key, header| request[header] = env[key] if env[key] }
      request
    end
  end
end
