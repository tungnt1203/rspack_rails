# frozen_string_literal: true

require "action_view"
require "json"
require "tmpdir"
require "rspack_rails/helper"

RSpec.describe RspackRails::Helper do
  let(:view) { ActionView::Base.empty.tap { |v| v.extend(described_class) } }
  let(:dev_server) { instance_double(RspackRails::DevServer) }

  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  before do
    allow(RspackRails).to receive_messages(dev_server: dev_server, manifest: RspackRails::Manifest.new(@root))
    allow(dev_server).to receive(:url) { |path| "/rspack/#{path}" }
  end

  def write_manifest(entries)
    path = @root.join(RspackRails::Manifest::PATH)
    path.dirname.mkpath
    path.write(JSON.generate(entries: entries))
  end

  # What `rspack serve` writes: every entry starts with the shared runtime.
  def write_dev_server_manifest
    write_manifest(
      application: { js: %w[runtime.js application.js], css: %w[application.css], stylesheetOnly: false },
      admin: { js: %w[runtime.js admin.js], css: [], stylesheetOnly: false },
      print: { js: %w[runtime.js print.js], css: %w[print.css], stylesheetOnly: true }
    )
  end

  context "when the dev server is running" do
    before do
      allow(dev_server).to receive(:running?).and_return(true)
      write_dev_server_manifest
    end

    it "loads each entry from the dev server, runtime.js once and first" do
      html = view.rspack_javascript_tag("application", "admin")
      expect(html.scan("/rspack/runtime.js").size).to eq(1)
      expect(html.index("runtime.js")).to be < html.index("application.js")
      expect(html).to include('src="/rspack/admin.js"')
      expect(html).to include("defer")
    end

    it "does not link runtime.js again in a later tag on the same page" do
      view.rspack_javascript_tag("application")
      expect(view.rspack_javascript_tag("admin")).not_to include("runtime.js")
    end

    it "gives a stylesheet-only entry's hot update script the stylesheet's nonce" do
      html = view.rspack_stylesheet_tag("print", nonce: "r4nd0m")
      expect(html).to include('href="/rspack/print.css" nonce="r4nd0m"')
      expect(html).to match(%r{<script src="/rspack/print\.js"[^>]* nonce="r4nd0m"})
    end

    it "links stylesheets from the dev server" do
      expect(view.rspack_stylesheet_tag("application")).to eq(
        '<link rel="stylesheet" href="/rspack/application.css">'
      )
    end

    it "drops integrity: the dev server is not part of the asset pipeline" do
      expect(view.rspack_javascript_tag("admin", integrity: true)).not_to include("integrity")
      expect(view.rspack_stylesheet_tag("application", integrity: true)).not_to include("integrity")
    end

    it "adds the script of a stylesheet-only entry for hot updates" do
      html = view.rspack_stylesheet_tag("application", "print", "admin")
      expect(html).to include('href="/rspack/print.css"')
      expect(html).to include('src="/rspack/print.js"')
      expect(html).to include('src="/rspack/runtime.js"')
      expect(html).not_to include('src="/rspack/admin.js"')
      expect(html).not_to include('src="/rspack/application.js"')
    end
  end

  context "when the dev server is not running" do
    before { allow(dev_server).to receive(:running?).and_return(false) }

    let(:entries) do
      { application: { js: %w[application-1a2b3c4d.js], css: %w[application-5e6f7a8b.css] },
        print: { js: [], css: %w[print-9c0d1e2f.css], stylesheetOnly: true } }
    end

    it "links the fingerprinted files the manifest lists under /rspack/" do
      write_manifest(entries)
      html = view.rspack_javascript_tag("application", "data-turbo-track": "reload")
      expect(html).to eq(
        '<script src="/rspack/application-1a2b3c4d.js" defer="defer" data-turbo-track="reload"></script>'
      )
      expect(view.rspack_stylesheet_tag("application"))
        .to eq('<link rel="stylesheet" href="/rspack/application-5e6f7a8b.css">')
      expect(view.rspack_stylesheet_tag("print")).not_to include("<script")
    end

    it "puts the asset host in front, as for any asset" do
      write_manifest(entries)
      view.config.asset_host = "https://cdn.example.com"
      expect(view.rspack_javascript_tag("application")).to include('src="https://cdn.example.com/rspack/application-1a2b3c4d.js"')
    end

    it "adds the Subresource Integrity hash of each file, and crossorigin with it" do
      write_manifest(entries)
      @root.join("public/rspack").mkpath
      @root.join("public/rspack/application-1a2b3c4d.js").write("console.log(1)")
      @root.join("public/rspack/application-5e6f7a8b.css").write("body{}")
      allow(RspackRails).to receive(:app_root).and_return(@root)
      script = %(sha384-#{Digest::SHA384.base64digest("console.log(1)")})
      style = %(sha384-#{Digest::SHA384.base64digest("body{}")})

      expect(view.rspack_javascript_tag("application", integrity: true))
        .to include(%(integrity="#{script}"), 'crossorigin="anonymous"')
      expect(view.rspack_stylesheet_tag("application", integrity: true))
        .to include(%(integrity="#{style}"), 'crossorigin="anonymous"')
    end

    it "fills in the Content Security Policy nonce for `nonce: true`" do
      write_manifest(entries)
      allow(view).to receive(:content_security_policy_nonce).and_return("n0nce")
      expect(view.rspack_javascript_tag("application", nonce: true)).to include('nonce="n0nce"')
      expect(view.rspack_stylesheet_tag("application", nonce: true)).to include('nonce="n0nce"')
    end

    it "links nothing for an entry without CSS" do
      write_manifest(admin: { js: %w[admin-1a2b3c4d.js], css: [] })
      expect(view.rspack_stylesheet_tag("admin")).to eq("")
    end

    it "raises before the first build, saying what to run" do
      expect { view.rspack_javascript_tag("application") }
        .to raise_error(RspackRails::Manifest::MissingEntry, %r{bin/dev, or run bin/rails rspack:build})
      expect { view.rspack_stylesheet_tag("application") }.to raise_error(RspackRails::Manifest::MissingEntry)
    end
  end

  describe "#rspack_asset_path and #rspack_image_tag" do
    before do
      write_manifest_with_assets("logo.svg" => "logo-3f2a9c1d5e6f7a8b.svg",
                                 "icons/menu.svg" => "menu-1a2b3c4d5e6f7a8b.svg")
    end

    def write_manifest_with_assets(assets)
      path = @root.join(RspackRails::Manifest::PATH)
      path.dirname.mkpath
      path.write(JSON.generate(entries: {}, assets: assets))
    end

    context "when the dev server is not running" do
      before { allow(dev_server).to receive(:running?).and_return(false) }

      it "gives the fingerprinted URL under /rspack/" do
        expect(view.rspack_asset_path("logo.svg")).to eq("/rspack/logo-3f2a9c1d5e6f7a8b.svg")
        expect(view.rspack_asset_path("icons/menu.svg")).to eq("/rspack/menu-1a2b3c4d5e6f7a8b.svg")
      end

      it "puts the asset host in front" do
        view.config.asset_host = "https://cdn.example.com"
        expect(view.rspack_asset_path("logo.svg")).to eq("https://cdn.example.com/rspack/logo-3f2a9c1d5e6f7a8b.svg")
      end

      it "writes an <img> with the options" do
        expect(view.rspack_image_tag("logo.svg", alt: "Acme", class: "h-8", "data-x": "1")).to eq(
          '<img src="/rspack/logo-3f2a9c1d5e6f7a8b.svg" alt="Acme" class="h-8" data-x="1">'
        )
      end

      it "raises for an image that is not in app/javascript/images" do
        expect { view.rspack_image_tag("nope.png") }.to raise_error(RspackRails::Manifest::MissingAsset)
      end
    end

    it "serves the image from the dev server while it runs" do
      allow(dev_server).to receive(:running?).and_return(true)
      expect(view.rspack_asset_path("logo.svg")).to eq("/rspack/logo-3f2a9c1d5e6f7a8b.svg")
    end
  end

  describe "#react_component" do
    it "takes props as keywords" do
      html = view.react_component("Hello", name: "World", count: 2)
      expect(html).to include('data-react-component="Hello"')
      expect(html).to include("data-react-props=\"{&quot;name&quot;:&quot;World&quot;,&quot;count&quot;:2}\"")
      expect(html).to start_with("<div")
    end

    it "takes a props hash plus HTML options" do
      html = view.react_component("admin/Chart", { title: "<b>" },
                                  html: { class: "chart", tag: :span, data: { x: "1" } })
      expect(html).to start_with('<span class="chart"')
      expect(html).to include('data-x="1"')
      expect(html).to include('data-react-component="admin/Chart"')
      expect(html).not_to include("<b>")
    end
  end
end
