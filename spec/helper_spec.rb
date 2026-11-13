# frozen_string_literal: true

require "action_view"
require "rspack_rails/helper"

RSpec.describe RspackRails::Helper do
  let(:view) { ActionView::Base.empty.tap { |v| v.extend(described_class) } }
  let(:dev_server) { instance_double(RspackRails::DevServer) }

  before do
    allow(RspackRails).to receive(:dev_server).and_return(dev_server)
    allow(dev_server).to receive(:url) { |path| "http://localhost:3036/#{path}" }
  end

  context "when the dev server is running" do
    before { allow(dev_server).to receive(:running?).and_return(true) }

    it "loads each entry from the dev server" do
      html = view.rspack_javascript_tag("application", "admin")
      expect(html).to include('src="http://localhost:3036/application.js"')
      expect(html).to include('src="http://localhost:3036/admin.js"')
      expect(html).to include("defer")
    end

    it "links stylesheets from the dev server" do
      expect(view.rspack_stylesheet_tag("application")).to include('href="http://localhost:3036/application.css"')
    end
  end

  context "when the dev server is not running" do
    before { allow(dev_server).to receive(:running?).and_return(false) }

    it "falls back to the asset pipeline" do
      html = view.rspack_javascript_tag("application", "data-turbo-track": "reload")
      expect(html).not_to include("3036")
      expect(html).to include("application.js")
      expect(html).to include('data-turbo-track="reload"')
    end
  end
end
