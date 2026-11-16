# frozen_string_literal: true

require "json"
require "tmpdir"
require "rspack_rails/manifest"

RSpec.describe RspackRails::Manifest do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  let(:manifest) { described_class.new(@root) }
  let(:path) { @root.join(described_class::PATH) }

  def write(entries, mtime = Time.now)
    path.dirname.mkpath
    path.write(JSON.generate(entries: entries))
    File.utime(mtime, mtime, path)
  end

  it "reads an entry's files" do
    write(print: { js: [], css: ["print.bundle.css"], stylesheetOnly: true })
    expect(manifest["print"]).to eq(
      described_class::Entry.new(scripts: [], stylesheets: ["print.bundle.css"], stylesheet_only: true)
    )
    expect(manifest[:print].stylesheet_only).to be(true)
  end

  it "falls back to the conventional names without a manifest or for an unknown entry" do
    expect(manifest["admin"]).to eq(
      described_class::Entry.new(scripts: ["admin.js"], stylesheets: ["admin.bundle.css"], stylesheet_only: false)
    )
    write(application: { js: ["application.js"], css: [] })
    expect(manifest["admin"].scripts).to eq(["admin.js"])
  end

  it "picks up a rewritten manifest" do
    write({ application: { js: ["application.js"] } }, Time.now - 10)
    expect(manifest["application"].scripts).to eq(["application.js"])
    write(application: { js: ["runtime.js", "application.js"] })
    expect(manifest["application"].scripts).to eq(["runtime.js", "application.js"])
  end

  it "treats a half-written manifest as missing" do
    path.dirname.mkpath
    path.write("{")
    expect(manifest["application"].scripts).to eq(["application.js"])
  end
end
