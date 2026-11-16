# frozen_string_literal: true

require "rspack_rails/rspack_version"

RSpec.describe RspackRails::RspackVersion do
  it "pins a package to the supported major" do
    expect(described_class.pin("@rspack/core")).to eq("@rspack/core@^2")
  end

  it "compares an installed version with the supported major" do
    expect(described_class.compare("2.3.2")).to eq(:supported)
    expect(described_class.compare("2.0.0-rc.3")).to eq(:supported)
    expect(described_class.compare("1.7.12")).to eq(:older)
    expect(described_class.compare("3.0.0-beta.1")).to eq(:newer)
  end
end
