# frozen_string_literal: true

require "tmpdir"
require "rspack_rails/app"

RSpec.describe RspackRails::App do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  let(:app) { described_class.new(@root.to_s) }

  def write(path, content = "")
    file = @root.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  it "reads files relative to the root, nil when missing" do
    write("Gemfile", "gem 'rails'")
    expect(app.root).to eq(@root)
    expect(app.read("Gemfile")).to eq("gem 'rails'")
    expect(app.read("missing.txt")).to be_nil
    expect(app.file?("Gemfile")).to be(true)
  end

  it "parses JSON, nil when missing or invalid" do
    write("good.json", '{"a": 1}')
    write("bad.json", "{")
    expect(app.json("good.json")).to eq("a" => 1)
    expect(app.json("bad.json")).to be_nil
    expect(app.json("missing.json")).to be_nil
  end

  it "reads package.json fresh each time, {} without one" do
    expect(app.package_json).to eq({})
    write("package.json", '{"devDependencies": {"@rspack/core": "^2"}}')
    expect(app.dependency?("@rspack/core")).to be(true)
    write("package.json", '{"dependencies": {"react": "^19"}}')
    expect(app.dependency?("@rspack/core")).to be(false)
    expect(app.dependency?("react")).to be(true)
  end

  it "reads an installed node module's package.json" do
    write("node_modules/@rspack/core/package.json", '{"version": "2.3.2"}')
    expect(app.node_package("@rspack/core")).to eq("version" => "2.3.2")
    expect(app.node_package("@rspack/cli")).to be_nil
  end

  it "finds layouts, entry points and the package manager" do
    write("app/views/layouts/application.html.erb")
    write("app/javascript/application.ts")
    write("app/javascript/entrypoints/admin.js")
    write("yarn.lock")
    expect(app.layouts).to eq(["app/views/layouts/application.html.erb"])
    expect(app.main_entry).to eq("app/javascript/application.ts")
    expect(app.entrypoints.keys).to eq(%w[application admin])
    expect(app.package_manager.name).to eq(:yarn)
  end
end
