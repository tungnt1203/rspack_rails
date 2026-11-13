# frozen_string_literal: true

require "json"
require "tmpdir"
require "rspack_rails/migration"

RSpec.describe RspackRails::Migration do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  def write(path, content = "")
    @root.join(path).dirname.mkpath
    @root.join(path).write(content)
  end

  let(:migration) { described_class.new(@root) }

  describe "#source" do
    it "detects importmap-rails" do
      write("config/importmap.rb", %(pin "application"\n))
      expect(migration.source).to eq(:importmap)
    end

    it "detects jsbundling-rails from the Gemfile" do
      write("Gemfile", %(gem "rails"\ngem "jsbundling-rails"\n))
      expect(migration.source).to eq(:jsbundling)
    end

    it "detects jsbundling from an esbuild build script" do
      write("package.json", JSON.generate(scripts: { build: "esbuild app/javascript/*.* --bundle" }))
      expect(migration.source).to eq(:jsbundling)
    end

    it "detects shakapacker and existing rspack setups" do
      write("config/shakapacker.yml")
      expect(migration.source).to eq(:shakapacker)
      write("rspack.config.mjs")
      expect(described_class.new(@root).source).to eq(:rspack)
    end

    it "returns :none for an app without a bundler" do
      expect(migration.source).to eq(:none)
    end
  end

  describe "importmap pins" do
    let(:importmap) do
      <<~RUBY
        # Pin npm packages by running ./bin/importmap

        pin "application"
        pin "@hotwired/turbo-rails", to: "turbo.min.js"
        pin "@hotwired/stimulus", to: "stimulus.min.js"
        pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
        pin_all_from "app/javascript/controllers", under: "controllers"
        pin "lodash" # @4.17.21
        pin "chart.js", to: "https://ga.jspm.io/npm:chart.js@4.4.1/dist/chart.js"
        pin "@rails/request.js", to: "https://ga.jspm.io/npm:@rails/request.js@0.0.9/src/index.js"
        pin "helpers", to: "helpers.js"
      RUBY
    end

    before do
      write("config/importmap.rb", importmap)
      write("app/javascript/helpers.js")
      write("vendor/javascript/lodash.js")
    end

    it "parses names, targets and versions" do
      lodash = migration.pins.find { |pin| pin.name == "lodash" }
      expect(lodash.version).to eq("4.17.21")
      expect(migration.pins.find { |pin| pin.name == "chart.js" }.version).to eq("4.4.1")
      expect(migration.pins.map(&:name)).not_to include("app/javascript/controllers")
    end

    it "keeps npm packages and drops app code and importmap-only helpers" do
      expect(migration.npm_packages).to eq(
        "@hotwired/turbo-rails" => nil,
        "@hotwired/stimulus" => nil,
        "lodash" => "4.17.21",
        "chart.js" => "4.4.1",
        "@rails/request.js" => "0.0.9"
      )
    end

    it "pins known versions in the install arguments" do
      expect(migration.npm_install_args).to include("lodash@4.17.21", "@rails/request.js@0.0.9", "@hotwired/stimulus")
    end

    it "lists vendored copies of npm packages" do
      expect(migration.vendored_files).to eq(["vendor/javascript/lodash.js"])
    end
  end

  it "reduces sub-path pins to their package" do
    write("config/importmap.rb", %(pin "@rails/actioncable/src", to: "actioncable.esm.js"\npin "lodash/debounce"\n))
    expect(migration.npm_packages.keys).to eq(["@rails/actioncable", "lodash"])
  end

  describe "jsbundling" do
    it "finds the previous bundler packages and configs" do
      write("package.json", JSON.generate(devDependencies: { "esbuild" => "^0.25", "@rspack/cli" => "^2" },
                                          dependencies: { "webpack" => "^5", "@hotwired/turbo-rails" => "^8" }))
      write("webpack.config.js")
      expect(migration.bundler_packages).to contain_exactly("esbuild", "webpack")
      expect(migration.bundler_configs).to eq(["webpack.config.js"])
    end

    it "lists root-level entries rspack would not build" do
      write("app/javascript/application.js")
      write("app/javascript/admin.js")
      write("app/javascript/controllers/hello_controller.js")
      expect(migration.extra_root_entries).to eq(["app/javascript/admin.js"])
    end
  end
end
