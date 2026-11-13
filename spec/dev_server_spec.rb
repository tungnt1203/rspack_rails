# frozen_string_literal: true

require "socket"

RSpec.describe RspackRails::DevServer do
  let(:server) { TCPServer.new("127.0.0.1", 0) }
  let!(:config) do
    RspackRails::Configuration.new({}).tap do |c|
      c.dev_server_host = "127.0.0.1"
      c.dev_server_port = server.addr[1]
      c.dev_server_enabled = true
    end
  end

  after { server.close unless server.closed? }

  it "is running when the port accepts connections" do
    expect(described_class.new(config, check_interval: 0).running?).to be(true)
  end

  it "is not running when nothing listens on the port" do
    server.close
    expect(described_class.new(config, check_interval: 0).running?).to be(false)
  end

  it "is not running when disabled" do
    config.dev_server_enabled = false
    expect(described_class.new(config, check_interval: 0).running?).to be(false)
  end

  it "caches the result within the check interval" do
    dev_server = described_class.new(config, check_interval: 60)
    expect(dev_server.running?).to be(true)
    server.close
    expect(dev_server.running?).to be(true)
  end

  it "builds same-origin URLs served through the proxy" do
    expect(described_class.new(config).url("/application.js")).to eq("/rspack/application.js")
    expect(described_class.new(config).url("admin.bundle.css")).to eq("/rspack/admin.bundle.css")
  end
end

RSpec.describe RspackRails::Configuration do
  it "reads host and port from the environment" do
    config = described_class.new("RSPACK_DEV_SERVER_HOST" => "0.0.0.0", "RSPACK_DEV_SERVER_PORT" => "4000")
    expect(config.dev_server_url).to eq("http://0.0.0.0:4000")
  end

  it "defaults to localhost:3036" do
    expect(described_class.new({}).dev_server_url).to eq("http://localhost:3036")
  end

  it "is disabled outside a Rails development environment" do
    expect(described_class.new({}).dev_server_enabled).to be(false)
  end
end
