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
      application: { js: %w[runtime.js application.js], css: %w[application.bundle.css], stylesheetOnly: false },
      admin: { js: %w[runtime.js admin.js], css: [], stylesheetOnly: false },
      print: { js: %w[runtime.js print.js], css: %w[print.bundle.css], stylesheetOnly: true }
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

    it "links stylesheets from the dev server" do
      expect(view.rspack_stylesheet_tag("application")).to eq(
        '<link rel="stylesheet" href="/rspack/application.bundle.css" />'
      )
    end

    it "drops integrity: the dev server is not part of the asset pipeline" do
      expect(view.rspack_javascript_tag("admin", integrity: true)).not_to include("integrity")
      expect(view.rspack_stylesheet_tag("application", integrity: true)).not_to include("integrity")
    end

    it "adds the script of a stylesheet-only entry for hot updates" do
      html = view.rspack_stylesheet_tag("application", "print", "admin")
      expect(html).to include('href="/rspack/print.bundle.css"')
      expect(html).to include('src="/rspack/print.js"')
      expect(html).to include('src="/rspack/runtime.js"')
      expect(html).not_to include('src="/rspack/admin.js"')
      expect(html).not_to include('src="/rspack/application.js"')
    end
  end

  context "when the dev server is not running" do
    before { allow(dev_server).to receive(:running?).and_return(false) }

    it "links the files the manifest lists from the asset pipeline" do
      write_manifest(application: { js: %w[application.js], css: %w[application.bundle.css] },
                     print: { js: [], css: %w[print.bundle.css], stylesheetOnly: true })
      html = view.rspack_javascript_tag("application", "data-turbo-track": "reload")
      expect(html).not_to include("/rspack/")
      expect(html).to include("application.js")
      expect(html).to include('data-turbo-track="reload"')
      expect(view.rspack_stylesheet_tag("print")).not_to include("<script")
    end

    it "passes integrity on to the asset pipeline" do
      write_manifest(application: { js: %w[application.js], css: %w[application.bundle.css] })
      allow(view).to receive(:javascript_include_tag).and_call_original
      allow(view).to receive(:stylesheet_link_tag).and_call_original
      view.rspack_javascript_tag("application", integrity: true)
      view.rspack_stylesheet_tag("application", integrity: true)
      expect(view).to have_received(:javascript_include_tag).with("application.js", defer: true, integrity: true)
      expect(view).to have_received(:stylesheet_link_tag).with("application.bundle.css", integrity: true)
    end

    it "links nothing for an entry without CSS" do
      write_manifest(admin: { js: %w[admin.js], css: [] })
      expect(view.rspack_stylesheet_tag("admin")).to eq("")
    end

    it "falls back to the conventional names before the first build" do
      expect(view.rspack_javascript_tag("application")).to include("application.js")
      html = view.rspack_stylesheet_tag("application", "admin")
      expect(html).to include("application.bundle.css")
      expect(html).to include("admin.bundle.css")
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
