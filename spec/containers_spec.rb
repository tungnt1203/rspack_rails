# frozen_string_literal: true

require "tmpdir"
require "rspack_rails/containers"

RSpec.describe RspackRails::Containers do
  # Files as `rails new --skip-javascript --devcontainer` (Rails 8.1) generates them.
  def fixture(name) = File.read(File.expand_path("fixtures/rails/#{name}", __dir__))

  def package_manager(lockfile = nil)
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, lockfile), "") if lockfile
      return RspackRails::PackageManager.new(dir)
    end
  end

  describe ".add_node_to_dockerfile" do
    let(:dockerfile) { described_class.add_node_to_dockerfile(fixture("Dockerfile"), package_manager) }

    it "installs Node.js in the build stage, before the gems" do
      build = dockerfile[/^FROM base AS build\n.*?^FROM base$/m]
      expect(build).to include("ARG NODE_VERSION=22.12.0", "/usr/local/node/bin:$PATH", "node-build")
      expect(build.index("node-build")).to be < build.index("bundle install")
    end

    it "installs node modules from the lockfile before copying the app, and drops them after precompile" do
      expect(dockerfile).to include("COPY package.json package-lock.json ./\nRUN npm ci\n\n# Copy application code")
      expect(dockerfile.index("RUN npm ci")).to be < dockerfile.index("COPY . .")
      expect(dockerfile).to match(/assets:precompile\n\nRUN rm -rf node_modules\n/)
      expect(dockerfile[/^FROM base$.*/m]).not_to include("node")
    end

    it "uses the app's package manager" do
      yarn = described_class.add_node_to_dockerfile(fixture("Dockerfile"), package_manager("yarn.lock"))
      expect(yarn).to include("RUN corepack enable", "COPY package.json yarn.lock ./", "yarn install --frozen-lockfile")
      bun = described_class.add_node_to_dockerfile(fixture("Dockerfile"), package_manager("bun.lock"))
      expect(bun).to include("RUN npm install -g bun", "COPY package.json bun.lock ./", "bun install --frozen-lockfile")
    end

    it "takes the Node.js version" do
      expect(described_class.add_node_to_dockerfile(fixture("Dockerfile"), package_manager, node_version: "24.1.0"))
        .to include("ARG NODE_VERSION=24.1.0")
    end

    it "is idempotent" do
      expect(described_class.add_node_to_dockerfile(dockerfile, package_manager)).to eq(dockerfile)
      expect(described_class.dockerfile_ready?(fixture("Dockerfile"))).to be(false)
      expect(described_class.dockerfile_ready?(dockerfile)).to be(true)
    end

    it "returns nil for a Dockerfile it does not recognize" do
      expect(described_class.add_node_to_dockerfile("FROM ruby\nCOPY . .\n", package_manager)).to be_nil
    end
  end

  describe ".add_node_to_devcontainer" do
    let(:devcontainer) { described_class.add_node_to_devcontainer(fixture("devcontainer.json"), 3036) }

    it "adds the Node.js feature and forwards the dev server port, keeping comments" do
      expect(devcontainer).to include(%(  "features": {\n    "ghcr.io/devcontainers/features/node:1": {},\n))
      expect(devcontainer).to include(%("forwardPorts": [3000, 3036]))
      expect(devcontainer).to start_with("// For format details")
    end

    it "is idempotent" do
      expect(described_class.add_node_to_devcontainer(devcontainer, 3036)).to eq(devcontainer)
      expect(described_class.devcontainer_ready?(devcontainer, 3036)).to be(true)
      expect(described_class.devcontainer_ready?(devcontainer, 4000)).to be(false)
    end
  end

  describe ".add_js_install_to_setup" do
    it "installs node modules right after the gems" do
      setup = described_class.add_js_install_to_setup(fixture("setup"), package_manager("pnpm-lock.yaml"))
      expect(setup).to include(
        %(system!("bundle install")\n\n  # Install JavaScript dependencies\n  system!("pnpm install")\n)
      )
      expect(described_class.add_js_install_to_setup(setup, package_manager)).to eq(setup)
    end
  end
end
