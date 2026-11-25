# frozen_string_literal: true

require "action_controller"
require "rack/mock"
require "tmpdir"
require "rspack_rails/static_files"

RSpec.describe RspackRails::StaticFiles do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      @root.join("application-1a2b3c4d.js").write("console.log(1)")
      @root.join(".rspack-manifest.json").write("{}")
      example.run
    end
  end

  let(:app) { ->(_env) { [404, { "content-type" => "text/plain" }, ["from the app"]] } }
  let(:request) { Rack::MockRequest.new(described_class.new(app, root: @root)) }

  it "serves a file under /rspack/ with a far-future cache header" do
    response = request.get("/rspack/application-1a2b3c4d.js")
    expect(response.status).to eq(200)
    expect(response.body).to eq("console.log(1)")
    expect(response.headers["cache-control"]).to eq("public, max-age=31536000, immutable")
    expect(response.headers["content-type"]).to include("javascript")
  end

  it "serves HEAD requests" do
    expect(request.head("/rspack/application-1a2b3c4d.js").status).to eq(200)
  end

  it "leaves a missing file to the app" do
    expect(request.get("/rspack/gone-1a2b3c4d.js").body).to eq("from the app")
  end

  it "leaves the manifests, which change with every build, to the app" do
    expect(request.get("/rspack/.rspack-manifest.json").body).to eq("from the app")
  end

  it "leaves other paths and methods to the app" do
    expect(request.get("/application-1a2b3c4d.js").body).to eq("from the app")
    expect(request.post("/rspack/application-1a2b3c4d.js").body).to eq("from the app")
  end

  it "does not leave the directory" do
    expect(request.get("/rspack/../spec_helper.rb").body).to eq("from the app")
    expect(request.get("/rspack/%2e%2e/etc/passwd").body).to eq("from the app")
  end
end
