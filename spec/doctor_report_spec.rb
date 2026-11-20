# frozen_string_literal: true

require "json"
require "stringio"
require "tmpdir"
require "rspack_rails/doctor"

# The doctor's full report for a few apps, compared with
# spec/fixtures/doctor/<name>.txt word for word. Every check runs in at least
# one of them, in each of its outcomes where it is cheap to set up, so a change
# to how the checks are organized cannot change what the doctor says.
# UPDATE_GOLDEN=1 rewrites the files after an intended change to the output.
RSpec.describe RspackRails::Doctor, "report" do
  let(:golden_dir) { File.expand_path("fixtures/doctor", __dir__) }
  let(:rails_fixtures) { File.expand_path("fixtures/rails", __dir__) }

  around do |example|
    Dir.mktmpdir do |dir|
      @root = Pathname(dir)
      example.run
    end
  end

  def write(path, content = "")
    file = @root.join(path)
    file.dirname.mkpath
    file.write(content)
  end

  def install_package(name, version: "2.3.2", engines: nil)
    data = { name: name, version: version, engines: engines }.compact
    write("node_modules/#{name}/package.json", JSON.generate(data))
  end

  def rspack_packages(version: "2.3.2")
    install_package("@rspack/core", version: version, engines: { node: "^20.19.0 || >=22.12.0" })
    install_package("@rspack/cli", version: version)
    install_package("@rspack/dev-server", version: version)
  end

  def report(enabled: true, running: true, node_version: "v22.12.0")
    config = RspackRails::Configuration.new({}).tap { |c| c.dev_server_enabled = enabled }
    dev_server = instance_double(RspackRails::DevServer, running?: running)
    io = StringIO.new
    described_class.new(@root, config: config, dev_server: dev_server, node_version: node_version).report(io)
    io.string.gsub(RspackRails::VERSION, "<VERSION>")
  end

  def expect_golden(name, actual)
    path = File.join(golden_dir, "#{name}.txt")
    if ENV["UPDATE_GOLDEN"] || !File.exist?(path)
      FileUtils.mkdir_p(golden_dir)
      File.write(path, actual)
    end
    expect(actual).to eq(File.read(path))
  end

  it "reports an empty directory" do
    expect_golden("empty", report(running: false))
  end

  it "reports a fully set up app" do
    rspack_packages
    install_package("@hotwired/stimulus")
    write("rspack.config.mjs", %(import { railsConfig } from "./config/rspack/rails.mjs";))
    RspackRails::ManagedFile.sync_all(@root)
    RspackRails::ManagedFile::STIMULUS.sync(@root, create: true)
    RspackRails::ManagedFile::REACT.sync(@root, create: true)
    write("package.json", JSON.generate(scripts: { build: "rspack build", dev: "rspack serve" }))
    write("app/javascript/application.js")
    write("app/javascript/entrypoints/print.css")
    write(RspackRails::Tailwind::STYLESHEET, RspackRails::Tailwind.add_excludes(%(@import "tailwindcss";\n)))
    write("app/assets/builds/application.js")
    write("app/assets/builds/application.bundle.css")
    write("app/assets/builds/print.bundle.css")
    tags = %(<%= rspack_javascript_tag "application" %>\n<%= rspack_stylesheet_tag "application" %>\n)
    write("app/views/layouts/application.html.erb", tags)
    write("app/views/layouts/admin.html.erb", tags)
    write("Procfile.dev", "web: bin/rails server\njs: npm run dev\n")
    pm = RspackRails::PackageManager.detect(@root)
    write("Dockerfile", RspackRails::Containers.add_node_to_dockerfile(File.read("#{rails_fixtures}/Dockerfile"), pm))
    write(".devcontainer/devcontainer.json",
          RspackRails::Containers.add_node_to_devcontainer(File.read("#{rails_fixtures}/devcontainer.json"), 3036))
    expect_golden("complete", report)
  end

  it "reports an app with something wrong in every check" do
    rspack_packages(version: "1.7.0")
    install_package("@rspack/core", version: "1.7.0", engines: { node: ">=22.12.0" })
    write("rspack.config.mjs", %(import { railsConfig } from "./config/rspack/rails.mjs";))
    write("config/rspack/rails.mjs", "#{RspackRails::ManagedFile::BASE.content}// edited\n")
    write(RspackRails::ManagedFile::STIMULUS.path, older_managed(RspackRails::ManagedFile::STIMULUS))
    write(RspackRails::ManagedFile::REACT.path, "// mine\n")
    write("package.json", JSON.generate(scripts: { start: "rspack serve" }))
    write("app/javascript/application.js")
    write(RspackRails::Tailwind::STYLESHEET, %(@import "tailwindcss";\n))
    write("app/assets/builds/print.bundle.css")
    write("app/views/layouts/application.html.erb",
          "<%= javascript_importmap_tags %>\n<%= stylesheet_link_tag :app %>\n")
    write("Procfile.dev", "web: bin/rails server\njs: npm run watch\n")
    write("Dockerfile", File.read("#{rails_fixtures}/Dockerfile"))
    write(".devcontainer/devcontainer.json", File.read("#{rails_fixtures}/devcontainer.json"))
    expect_golden("broken", report(running: false, node_version: "v20.0.0"))
  end

  it "reports the remaining outcomes" do
    rspack_packages(version: "3.0.0")
    write("rspack.config.mjs", "export default {};\n")
    write("package.json", JSON.generate(scripts: { build: "rspack build" }))
    write("app/javascript/entrypoints/admin.js")
    write("app/assets/builds/application.bundle.css")
    write("app/views/layouts/application.html.erb", "<%= yield %>\n")
    write("Procfile.dev", "web: bin/rails server\n")
    expect_golden("other", report(enabled: false))
  end

  it "reports a stale config and a missing rspack:install" do
    rspack_packages
    write("rspack.config.mjs", %(import { railsConfig } from "./config/rspack/rails.mjs";))
    write("app/javascript/application.js")
    write("app/views/layouts/application.html.erb", %(<%= rspack_javascript_tag "application" %>\n))
    write("app/assets/builds/application.bundle.css")
    expect_golden("partial", report(node_version: "v22.12.0"))
    write("config/rspack/rails.mjs", older_managed)
    write("app/javascript/controllers/autoload.js", RspackRails::ManagedFile::STIMULUS.content)
    expect_golden("outdated", report)
  end
end
