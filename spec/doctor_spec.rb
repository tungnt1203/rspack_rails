# frozen_string_literal: true

require "json"
require "stringio"
require "tmpdir"
require "rspack_rails/doctor"

RSpec.describe RspackRails::Doctor do
  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  let(:config) { RspackRails::Configuration.new({}).tap { |c| c.dev_server_enabled = true } }
  let(:dev_server) { instance_double(RspackRails::DevServer, running?: true) }

  def write(path, content = "")
    file = @root.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  def install_package(name, version: "2.3.2", engines: nil)
    data = { name: name, version: version, engines: engines }.compact
    write("node_modules/#{name}/package.json", JSON.generate(data))
  end

  def doctor(node_version: "v22.12.0")
    described_class.new(@root, config: config, dev_server: dev_server, node_version: node_version)
  end

  def check(name, **options)
    doctor(**options).checks.find { |c| c.name == name }
  end

  def set_up_complete_app
    install_package("@rspack/core", engines: { node: "^20.19.0 || >=22.12.0" })
    install_package("@rspack/cli")
    install_package("@rspack/dev-server")
    write("rspack.config.mjs")
    write("package.json", JSON.generate(scripts: { build: "rspack build", dev: "rspack serve" }))
    write("app/javascript/application.js")
    write("app/assets/builds/application.js", "console.log(1)")
    write("app/views/layouts/application.html.erb", '<%= rspack_javascript_tag "application" %>')
    write("Procfile.dev", "web: bin/rails server\njs: npm run dev\n")
  end

  it "passes a fully set up app" do
    set_up_complete_app
    expect(doctor.checks.map(&:status).uniq).to eq([:ok])
    expect(doctor).to be_ok
    expect(doctor.summary).to eq("Everything looks good.")
  end

  it "reports an empty directory as failing" do
    expect(doctor).not_to be_ok
    expect(check("rspack.config.mjs").status).to eq(:error)
    expect(check("@rspack/core").hint).to eq("Run `npm install --save-dev @rspack/core`")
  end

  it "flags a Node.js version rspack does not support" do
    set_up_complete_app
    node = check("Node.js", node_version: "v20.18.0")
    expect(node.status).to eq(:error)
    expect(node.detail).to include("^20.19.0 || >=22.12.0")
  end

  it "reports a missing node binary" do
    allow(Open3).to receive(:capture2).and_raise(Errno::ENOENT)
    expect(described_class.new(@root, config: config, dev_server: dev_server).checks.first.detail)
      .to eq("not found")
  end

  it "warns when importmap tags are still in the layout" do
    set_up_complete_app
    write("app/views/layouts/application.html.erb", "<%= javascript_importmap_tags %>")
    expect(check("Layout").status).to eq(:warn)
  end

  it "requires @hotwired/stimulus once autoload is installed" do
    set_up_complete_app
    write("app/javascript/controllers/autoload.js")
    expect(check("Stimulus").status).to eq(:error)
    install_package("@hotwired/stimulus")
    expect(check("Stimulus").status).to eq(:ok)
  end

  it "warns when the dev server is not running" do
    set_up_complete_app
    allow(dev_server).to receive(:running?).and_return(false)
    expect(check("Dev server").detail).to eq("not running at http://localhost:3036")
  end

  it "prints a report with hints" do
    io = StringIO.new
    doctor.report(io)
    expect(io.string).to include("✗ rspack.config.mjs: missing\n    → Run `bin/rails rspack:install`")
  end
end
