# frozen_string_literal: true

RSpec.describe RspackRails do
  it "has a version number" do
    expect(RspackRails::VERSION).not_to be_nil
  end

  it "deprecates toward 2.0" do
    expect(described_class.deprecator.deprecation_horizon).to eq("2.0")
  end

  describe ".manifest" do
    after { described_class.instance_variable_set(:@manifest, nil) }

    it "keeps one manifest per app root" do
      first = described_class.manifest
      expect(described_class.manifest).to be(first)
      expect(first.root).to eq(Pathname(Dir.pwd))
    end

    it "reads another app's manifest when the root changes" do
      Dir.mktmpdir do |dir|
        described_class.manifest
        Dir.chdir(dir) { expect(described_class.manifest.root).to eq(Pathname(Dir.pwd)) }
      end
    end
  end
end
