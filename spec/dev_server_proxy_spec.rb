# frozen_string_literal: true

require "socket"
require "rspack_rails/dev_server_proxy"

RSpec.describe RspackRails::DevServerProxy do
  let(:app) { ->(_env) { [200, { "content-type" => "text/plain" }, ["rails"]] } }
  let(:requests) { Queue.new }
  let(:server) { TCPServer.new("127.0.0.1", 0) }
  let(:config) do
    RspackRails::Configuration.new({}).tap do |c|
      c.dev_server_host = "127.0.0.1"
      c.dev_server_port = server.addr[1]
      c.dev_server_enabled = true
    end
  end
  let(:proxy) { described_class.new(app, config: config) }

  # A one-request HTTP server standing in for `rspack serve`.
  def serve(status: "200 OK", body: "console.log(1)")
    Thread.new do
      client = server.accept
      requests << read_request(client)
      client.write "HTTP/1.1 #{status}\r\nContent-Type: text/javascript\r\nContent-Length: #{body.bytesize}\r\n" \
                   "Connection: close\r\n\r\n#{body}"
      client.close
    end
  end

  def read_request(client)
    lines = []
    while (line = client.gets) && line != "\r\n"
      lines << line
    end
    lines
  end

  def env(path, method: "GET", query: "")
    { "PATH_INFO" => path, "REQUEST_METHOD" => method, "QUERY_STRING" => query }
  end

  after { server.close unless server.closed? }

  it "forwards /rspack/ requests to the dev server" do
    thread = serve
    status, headers, body = proxy.call(env("/rspack/application.js", query: "v=1"))
    thread.join

    expect(status).to eq(200)
    expect(body.join).to eq("console.log(1)")
    expect(headers["content-type"]).to eq("text/javascript")
    expect(headers).not_to include("connection", "content-length")
    expect(requests.pop.first).to eq("GET /application.js?v=1 HTTP/1.1\r\n")
  end

  it "passes the dev server status through" do
    thread = serve(status: "404 Not Found", body: "missing")
    status, = proxy.call(env("/rspack/nope.js"))
    thread.join
    expect(status).to eq(404)
  end

  it "leaves other paths to the app" do
    expect(proxy.call(env("/assets/application.js")).last).to eq(["rails"])
  end

  it "leaves non-GET requests to the app" do
    expect(proxy.call(env("/rspack/application.js", method: "POST")).last).to eq(["rails"])
  end

  it "does nothing while the dev server is disabled" do
    config.dev_server_enabled = false
    expect(proxy.call(env("/rspack/application.js")).last).to eq(["rails"])
  end

  it "answers 502 when the dev server is down" do
    proxy # resolve the port before closing it
    server.close
    status, _, body = proxy.call(env("/rspack/application.js"))
    expect(status).to eq(502)
    expect(body.join).to include("not reachable")
  end
end
