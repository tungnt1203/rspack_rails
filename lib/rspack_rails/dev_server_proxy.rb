# frozen_string_literal: true

require "net/http"
require "uri"

module RspackRails
  # Serves `rspack serve` output through the Rails app under /rspack/, so
  # scripts, chunks, workers and hot updates are same-origin with the page.
  # Browsers refuse to start a Web Worker from another origin, which is what
  # loading straight from localhost:3036 would be. Lazy compilation requests
  # (POST /rspack/_rspack/lazy/trigger) come through here too; only the HMR
  # websocket goes to the dev server directly.
  class DevServerProxy
    PREFIX = "/rspack/"
    # Where the lazy compilation client posts the modules a page needs compiled.
    LAZY_COMPILATION = "#{PREFIX}_rspack/lazy/trigger".freeze
    # Response headers that describe the dev server connection, not the body.
    SKIPPED_HEADERS = %w[connection keep-alive transfer-encoding upgrade proxy-connection te trailer
                         content-length content-encoding].freeze
    FORWARDED_HEADERS = { "HTTP_IF_NONE_MATCH" => "If-None-Match", "HTTP_ACCEPT" => "Accept" }.freeze
    REQUEST_CLASSES = { "GET" => Net::HTTP::Get, "HEAD" => Net::HTTP::Head, "POST" => Net::HTTP::Post }.freeze

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
      path = env["PATH_INFO"].to_s
      return false unless path.start_with?(PREFIX) && @config.dev_server_enabled

      case env["REQUEST_METHOD"]
      when "GET", "HEAD" then true
      when "POST" then path == LAZY_COMPILATION
      else false
      end
    end

    def proxy(env)
      # A request made while rspack is compiling waits for the build to finish.
      response = Net::HTTP.start(@config.dev_server_host, @config.dev_server_port,
                                 open_timeout: 1, read_timeout: 120) { |http| http.request(build_request(env)) }

      headers = response.each_header.to_h.except(*SKIPPED_HEADERS)
      [response.code.to_i, headers, [response.body.to_s]]
    end

    def build_request(env)
      request = REQUEST_CLASSES.fetch(env["REQUEST_METHOD"]).new(upstream_path(env))
      FORWARDED_HEADERS.each { |key, header| request[header] = env[key] if env[key] }
      forward_body(request, env) if request.request_body_permitted?
      request
    end

    # /rspack/application.js -> /application.js: the dev server serves from
    # its root, which also covers configs generated before the proxy existed.
    def upstream_path(env)
      path = env["PATH_INFO"].delete_prefix(PREFIX.chomp("/"))
      env["QUERY_STRING"].to_s.empty? ? path : "#{path}?#{env["QUERY_STRING"]}"
    end

    # The lazy compilation client's list of modules (text/plain).
    def forward_body(request, env)
      request.body = env["rack.input"]&.read.to_s
      request.content_type = env["CONTENT_TYPE"] if env["CONTENT_TYPE"]
    end
  end
end
