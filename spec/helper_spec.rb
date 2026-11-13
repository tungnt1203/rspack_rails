# frozen_string_literal: true

require "action_view"
require "tmpdir"
require "rspack_rails/helper"

RSpec.describe RspackRails::Helper do
  let(:view) { ActionView::Base.empty.tap { |v| v.extend(described_class) } }
  let(:dev_server) { instance_double(RspackRails::DevServer) }

  before do
    allow(RspackRails).to receive(:dev_server).and_return(dev_server)
    allow(dev_server).to receive(:url) { |path| "/rspack/#{path}" }
  end

  context "when the dev server is running" do
    before { allow(dev_server).to receive(:running?).and_return(true) }

    it "loads each entry from the dev server" do
      html = view.rspack_javascript_tag("application", "admin")
      expect(html).to include('src="/rspack/application.js"')
      expect(html).to include('src="/rspack/admin.js"')
      expect(html).to include("defer")
    end

    it "links stylesheets from the dev server" do
      expect(view.rspack_stylesheet_tag("application")).to include('href="/rspack/application.bundle.css"')
    end
  end

  context "when the dev server is not running" do
    before { allow(dev_server).to receive(:running?).and_return(false) }

    it "falls back to the asset pipeline" do
      html = view.rspack_javascript_tag("application", "data-turbo-track": "reload")
      expect(html).not_to include("/rspack/")
      expect(html).to include("application.js")
      expect(html).to include('data-turbo-track="reload"')
    end

    it "links the extracted .bundle.css from the asset pipeline" do
      html = view.rspack_stylesheet_tag("application", "admin")
      expect(html).to include("application.bundle.css")
      expect(html).to include("admin.bundle.css")
      expect(html).not_to include("/rspack/")
    end
  end

  describe "shared runtime and stylesheet entrypoints" do
    around do |example|
      Dir.mktmpdir do |dir|
        @root = Pathname(dir)
        example.run
      end
    end

    before do
      allow(view).to receive(:rspack_root).and_return(@root)
      @root.join("app/javascript/entrypoints").mkpath
      @root.join("app/javascript/entrypoints/print.scss").write("")
      @root.join("app/javascript/entrypoints/admin.js").write("")
    end

    context "when the dev server is running" do
      before { allow(dev_server).to receive(:running?).and_return(true) }

      it "links runtime.js once per page, before the entries" do
        first = view.rspack_javascript_tag("application", "admin")
        second = view.rspack_javascript_tag("checkout")
        expect(first.scan("/rspack/runtime.js").size).to eq(1)
        expect(first.index("runtime.js")).to be < first.index("application.js")
        expect(second).not_to include("runtime.js")
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

      it "links the dev server's runtime.js while it is still in app/assets/builds" do
        expect(view.rspack_javascript_tag("application")).not_to include("runtime")
        @root.join("app/assets/builds").mkpath
        @root.join("app/assets/builds/runtime.js").write("")
        fresh_view = ActionView::Base.empty.tap { |v| v.extend(described_class) }
        allow(fresh_view).to receive(:rspack_root).and_return(@root)
        expect(fresh_view.rspack_javascript_tag("application")).to include("runtime.js")
      end

      it "links only the stylesheet of a stylesheet-only entry" do
        html = view.rspack_stylesheet_tag("print")
        expect(html).to include("print.bundle.css")
        expect(html).not_to include("<script")
      end
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
