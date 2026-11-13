# frozen_string_literal: true

require "tmpdir"
require "rspack_rails/entrypoints"

RSpec.describe RspackRails::Entrypoints do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  def write(path)
    @root.join(path).dirname.mkpath
    @root.join(path).write("")
  end

  it "finds nothing in an empty app" do
    expect(described_class.discover(@root)).to eq({})
  end

  it "finds application.js and every entrypoint, named after the file" do
    write("app/javascript/application.js")
    write("app/javascript/entrypoints/admin.js")
    write("app/javascript/entrypoints/checkout.ts")
    write("app/javascript/entrypoints/notes.md")

    expect(described_class.discover(@root)).to eq(
      "application" => "app/javascript/application.js",
      "admin" => "app/javascript/entrypoints/admin.js",
      "checkout" => "app/javascript/entrypoints/checkout.ts"
    )
  end

  it "accepts application.ts" do
    write("app/javascript/application.ts")
    expect(described_class.discover(@root)).to eq("application" => "app/javascript/application.ts")
  end

  it "works with only entrypoints" do
    write("app/javascript/entrypoints/admin.js")
    expect(described_class.discover(@root).keys).to eq(["admin"])
  end
end
