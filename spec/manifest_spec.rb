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
    write(print: { js: [], css: ["print-9c0d1e2f.css"], stylesheetOnly: true })
    expect(manifest["print"]).to eq(
      described_class::Entry.new(scripts: [], stylesheets: ["print-9c0d1e2f.css"], stylesheet_only: true)
    )
    expect(manifest[:print].stylesheet_only).to be(true)
  end

  it "says what to run when there is no manifest" do
    expect { manifest["admin"] }
      .to raise_error(described_class::MissingEntry, %r{"admin" in public/rspack/.*bin/dev.*rspack:build})
  end

  it "names the entries it has when asked for an unknown one" do
    write(application: { js: ["application-1a2b3c4d.js"], css: [] })
    expect { manifest["admin"] }.to raise_error(described_class::MissingEntry, /it has application.*restart/m)
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
    expect { manifest["application"] }.to raise_error(described_class::MissingEntry)
  end

  it "keeps the last complete manifest while rspack rewrites it, then reads the new one" do
    write({ application: { js: ["runtime.js", "application.js"] } }, Time.now - 10)
    expect(manifest["application"].scripts).to eq(["runtime.js", "application.js"])

    path.write("")
    File.utime(Time.now - 5, Time.now - 5, path)
    expect(manifest["application"].scripts).to eq(["runtime.js", "application.js"])

    path.write(JSON.generate(entries: { application: { js: ["application.js"] } }))
    File.utime(Time.now - 5, Time.now - 5, path)
    expect(manifest["application"].scripts).to eq(["application.js"])
  end
end
