# frozen_string_literal: true

require "rspack_rails/node_version"

RSpec.describe RspackRails::NodeVersion do
  {
    ["v20.19.0", "^20.19.0 || >=22.12.0"] => true,
    ["v20.18.1", "^20.19.0 || >=22.12.0"] => false,
    ["v21.0.0", "^20.19.0 || >=22.12.0"] => false,
    ["v22.11.0", "^20.19.0 || >=22.12.0"] => false,
    ["v26.5.1", "^20.19.0 || >=22.12.0"] => true,
    ["v18.20.0", ">=18 <19"] => true,
    ["v19.0.0", ">=18 <19"] => false,
    ["v20.5.3", "~20.5.0"] => true,
    ["v20.6.0", "~20.5.0"] => false,
    ["v20.1.0", "20"] => true,
    ["v20.1.0", "20.x"] => true,
    ["v21.1.0", "20.x"] => false
  }.each do |(version, range), expected|
    it "#{expected ? "accepts" : "rejects"} #{version} for #{range}" do
      expect(described_class.check(version, range)).to be(expected)
    end
  end

  it "returns nil for ranges it cannot read" do
    expect(described_class.check("v20.0.0", "18 - 20")).to be_nil
  end

  it "returns nil for an unparseable version" do
    expect(described_class.check("garbage", ">=18")).to be_nil
  end
end
