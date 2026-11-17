# frozen_string_literal: true

RSpec.describe RspackRails do
  it "has a version number" do
    expect(RspackRails::VERSION).not_to be_nil
  end

  it "deprecates toward 2.0" do
    expect(described_class.deprecator.deprecation_horizon).to eq("2.0")
  end
end
