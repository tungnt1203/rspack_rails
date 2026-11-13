# frozen_string_literal: true

require "tmpdir"

RSpec.describe RspackRails::PackageManager do
  def detect_with(*files)
    Dir.mktmpdir do |dir|
      files.each { |f| File.write(File.join(dir, f), "") }
      return described_class.detect(dir)
    end
  end

  it "defaults to npm" do
    expect(detect_with.name).to eq(:npm)
  end

  {
    "bun.lock" => :bun, "bun.lockb" => :bun, "yarn.lock" => :yarn,
    "pnpm-lock.yaml" => :pnpm, "package-lock.json" => :npm
  }.each do |lockfile, manager|
    it "detects #{manager} from #{lockfile}" do
      expect(detect_with(lockfile).name).to eq(manager)
    end
  end

  it "builds commands for the detected manager" do
    pm = detect_with("yarn.lock")
    expect(pm.install_command).to eq("yarn install")
    expect(pm.add_command("@hotwired/stimulus")).to eq("yarn add @hotwired/stimulus")
    expect(pm.run_command("build")).to eq("yarn run build")
    expect(pm.add_dev_command("@rspack/cli", "@rspack/core")).to eq("yarn add --dev @rspack/cli @rspack/core")
  end
end
