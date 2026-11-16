# frozen_string_literal: true

module RspackRails
  # Detects the JavaScript package manager of an app from its lockfile and
  # builds the shell commands rspack_rails needs.
  class PackageManager
    LOCKFILES = {
      bun: %w[bun.lock bun.lockb],
      yarn: %w[yarn.lock],
      pnpm: %w[pnpm-lock.yaml],
      npm: %w[package-lock.json]
    }.freeze

    INSTALL = {
      bun: "bun install",
      yarn: "yarn install",
      pnpm: "pnpm install",
      npm: "npm install"
    }.freeze

    ADD = {
      bun: "bun add",
      yarn: "yarn add",
      pnpm: "pnpm add",
      npm: "npm install"
    }.freeze

    ADD_DEV = {
      bun: "bun add --dev",
      yarn: "yarn add --dev",
      pnpm: "pnpm add --save-dev",
      npm: "npm install --save-dev"
    }.freeze

    # Installs exactly what the lockfile says (Docker builds, CI).
    FROZEN_INSTALL = {
      bun: "bun install --frozen-lockfile",
      yarn: "yarn install --frozen-lockfile",
      pnpm: "pnpm install --frozen-lockfile",
      npm: "npm ci"
    }.freeze

    attr_reader :root, :name

    def self.detect(root = Dir.pwd)
      new(root)
    end

    def initialize(root)
      @root = root.to_s
      @name, @lockfile = LOCKFILES.lazy.flat_map { |name, files| files.map { |file| [name, file] } }
                                  .find { |_, file| File.exist?(File.join(@root, file)) }
      @name ||= :npm
    end

    def install_command
      INSTALL.fetch(name)
    end

    def frozen_install_command
      FROZEN_INSTALL.fetch(name)
    end

    # The app's lockfile, or the usual name for this package manager.
    def lockfile
      @lockfile || LOCKFILES.fetch(name).first
    end

    def add_command(*packages)
      [ADD.fetch(name), *packages].join(" ")
    end

    def add_dev_command(*packages)
      [ADD_DEV.fetch(name), *packages].join(" ")
    end

    def run_command(script)
      "#{name} run #{script}"
    end
  end
end
