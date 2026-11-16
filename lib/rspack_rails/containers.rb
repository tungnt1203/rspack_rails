# frozen_string_literal: true

module RspackRails
  # Edits to the files Rails generates for containers, so an app built with
  # rspack works in them: the Dockerfile (Kamal deploys run assets:precompile,
  # which runs rspack), .devcontainer/devcontainer.json and bin/setup.
  # Pure text transforms: each returns the new content, or nil when the file
  # does not have the shape Rails generates.
  module Containers
    NODE_IN_DOCKERFILE = %r{node-build|NODE_VERSION|/usr/local/node|nodejs|^FROM node}
    NODE_MODULES_IN_DOCKERFILE = /\b(npm ci|npm install|yarn install|pnpm install|bun install)\b/
    JS_INSTALL_IN_SETUP = /\b(npm (ci|install)|yarn install|pnpm install|bun install|rspack:dependencies)\b/
    NODE_FEATURE = "ghcr.io/devcontainers/features/node:1"
    DEFAULT_NODE_VERSION = "22.12.0"

    module_function

    # The Node.js version for the Dockerfile: NODE_VERSION, the local node, or an LTS.
    def local_node_version
      ENV.fetch("NODE_VERSION") { `node --version 2>/dev/null`[/\d+\.\d+\.\d+/] || DEFAULT_NODE_VERSION }
    rescue SystemCallError
      DEFAULT_NODE_VERSION
    end

    def dockerfile_ready?(content)
      content.match?(NODE_IN_DOCKERFILE) && content.match?(NODE_MODULES_IN_DOCKERFILE)
    end

    # Installs Node.js in the build stage, installs node modules before the
    # app is copied (so the layer caches), and drops them after precompile.
    def add_node_to_dockerfile(content, package_manager, node_version: DEFAULT_NODE_VERSION)
      return content if dockerfile_ready?(content)

      build_packages = %r{(^FROM \S+ AS build\n.*?rm -rf /var/lib/apt/lists /var/cache/apt/archives\n)}m
      copy_app = /^# Copy application code\n/
      return unless content.match?(build_packages) && content.match?(copy_app)

      node = install_node(package_manager, node_version)
      content = content.sub(build_packages) { "#{::Regexp.last_match(1)}\n#{node}" }
      content = content.sub(copy_app) { "#{install_node_modules(package_manager)}\n#{::Regexp.last_match(0)}" }
      content.sub(%r{^(RUN .*bin/rails assets:precompile\n)}) { "#{::Regexp.last_match(1)}\nRUN rm -rf node_modules\n" }
    end

    def install_node(package_manager, node_version)
      tools = { yarn: "RUN corepack enable\n", pnpm: "RUN corepack enable\n", bun: "RUN npm install -g bun\n" }
      <<~DOCKERFILE
        # Install Node.js: assets:precompile runs rspack (rspack_rails)
        ARG NODE_VERSION=#{node_version}
        ENV PATH=/usr/local/node/bin:$PATH
        RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \\
            /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \\
            rm -rf /tmp/node-build-master
        #{tools[package_manager.name]}
      DOCKERFILE
        .sub(/\n\n\z/, "\n")
    end

    def install_node_modules(package_manager)
      <<~DOCKERFILE
        # Install node modules
        COPY package.json #{package_manager.lockfile} ./
        RUN #{package_manager.frozen_install_command}
      DOCKERFILE
    end

    def devcontainer_ready?(content, port)
      content.include?("features/node") && forwards?(content, port)
    end

    # devcontainer.json is JSON with comments, so it is edited as text.
    def add_node_to_devcontainer(content, port)
      content = add_node_feature(content) unless content.include?("features/node")
      content = add_forwarded_port(content, port) if content && !forwards?(content, port)
      content
    end

    def add_node_feature(content)
      features = /^(\s*)"features": \{\n/
      return unless content.match?(features)

      content.sub(features) { "#{::Regexp.last_match(0)}#{::Regexp.last_match(1)}  \"#{NODE_FEATURE}\": {},\n" }
    end

    # The HMR websocket connects to the dev server directly, not through Rails.
    def add_forwarded_port(content, port)
      return unless content.match?(/"forwardPorts": \[[^\]]*\]/)

      content.sub(/("forwardPorts": \[[^\]]*?)\s*\]/) { "#{::Regexp.last_match(1)}, #{port}]" }
    end

    def forwards?(content, port)
      content[/"forwardPorts": \[([^\]]*)\]/, 1].to_s.scan(/\d+/).include?(port.to_s)
    end

    def setup_ready?(content)
      content.match?(JS_INSTALL_IN_SETUP)
    end

    # bin/setup (also run by the devcontainer's postCreateCommand) installs
    # node modules after the gems.
    def add_js_install_to_setup(content, package_manager)
      return content if setup_ready?(content)

      bundle = /^(\s*)system\("bundle check"\) \|\| system!\("bundle install"\)\n/
      return unless content.match?(bundle)

      content.sub(bundle) do
        indent = ::Regexp.last_match(1)
        "#{::Regexp.last_match(0)}\n#{indent}# Install JavaScript dependencies\n" \
          "#{indent}system!(\"#{package_manager.install_command}\")\n"
      end
    end
  end
end
