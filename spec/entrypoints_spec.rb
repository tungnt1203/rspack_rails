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
      "application" => ["app/javascript/application.js"],
      "admin" => ["app/javascript/entrypoints/admin.js"],
      "checkout" => ["app/javascript/entrypoints/checkout.ts"]
    )
  end

  it "accepts application.ts and JSX/TSX entrypoints" do
    write("app/javascript/application.ts")
    write("app/javascript/entrypoints/dashboard.tsx")
    expect(described_class.discover(@root)).to eq(
      "application" => ["app/javascript/application.ts"],
      "dashboard" => ["app/javascript/entrypoints/dashboard.tsx"]
    )
  end

  it "finds stylesheet entrypoints and merges them with a script of the same name" do
    write("app/javascript/entrypoints/print.css")
    write("app/javascript/entrypoints/mailer.scss")
    write("app/javascript/entrypoints/admin.js")
    write("app/javascript/entrypoints/admin.css")
    entries = described_class.discover(@root)

    expect(entries["admin"]).to eq(%w[app/javascript/entrypoints/admin.css app/javascript/entrypoints/admin.js])
    expect(described_class.css_only?(entries["print"])).to be(true)
    expect(described_class.css_only?(entries["mailer"])).to be(true)
    expect(described_class.css_only?(entries["admin"])).to be(false)
  end

  it "works with only entrypoints" do
    write("app/javascript/entrypoints/admin.js")
    expect(described_class.discover(@root).keys).to eq(["admin"])
  end
end
