# frozen_string_literal: true

RSpec.describe RspackRails::Configuration do
  it "defaults to localhost:3036" do
    config = described_class.new({})
    expect(config.dev_server_url).to eq("http://localhost:3036")
  end

  it "reads host and port from the environment" do
    config = described_class.new("RSPACK_DEV_SERVER_HOST" => "0.0.0.0", "RSPACK_DEV_SERVER_PORT" => "4000")
    expect(config.dev_server_url).to eq("http://0.0.0.0:4000")
  end

  it "rejects a port that is not a number" do
    expect { described_class.new("RSPACK_DEV_SERVER_PORT" => "abc") }.to raise_error(ArgumentError)
  end

  it "is switched off by RSPACK_DEV_SERVER=false" do
    expect(described_class.new("RSPACK_DEV_SERVER" => "false").dev_server_enabled).to be(false)
  end

  it "is off outside a Rails app" do
    expect(described_class.new({}).dev_server_enabled).to be(false)
  end

  it "prefers an explicit setting over the environment" do
    config = described_class.new("RSPACK_DEV_SERVER" => "false")
    config.dev_server_enabled = true
    expect(config.dev_server_enabled).to be(true)
  end
end
