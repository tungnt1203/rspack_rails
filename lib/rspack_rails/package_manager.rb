# frozen_string_literal: true

module RspackRails
  # Detects the JavaScript package manager of an app from its lockfile and
  # builds the shell commands rspack_rails needs.
  class PackageManager
    # frozen_install installs exactly what the lockfile says (Docker builds, CI).
    Commands = Data.define(:lockfiles, :install, :frozen_install, :add, :add_dev)

    # In detection order: an app with both bun.lock and package-lock.json is a bun app.
    MANAGERS = {
      bun: Commands.new(lockfiles: %w[bun.lock bun.lockb], install: "bun install",
                        frozen_install: "bun install --frozen-lockfile", add: "bun add", add_dev: "bun add --dev"),
      yarn: Commands.new(lockfiles: %w[yarn.lock], install: "yarn install",
                         frozen_install: "yarn install --frozen-lockfile", add: "yarn add", add_dev: "yarn add --dev"),
      pnpm: Commands.new(lockfiles: %w[pnpm-lock.yaml], install: "pnpm install",
                         frozen_install: "pnpm install --frozen-lockfile", add: "pnpm add",
                         add_dev: "pnpm add --save-dev"),
      npm: Commands.new(lockfiles: %w[package-lock.json], install: "npm install",
                        frozen_install: "npm ci", add: "npm install", add_dev: "npm install --save-dev")
    }.freeze

    attr_reader :root, :name

    def self.detect(root = Dir.pwd)
      new(root)
    end

    def initialize(root)
      @root = root.to_s
      @name, @lockfile = MANAGERS.lazy.flat_map { |name, commands| commands.lockfiles.map { |file| [name, file] } }
                                 .find { |_, file| File.exist?(File.join(@root, file)) }
      @name ||= :npm
    end

    def install_command
      commands.install
    end

    def frozen_install_command
      commands.frozen_install
    end

    # The app's lockfile, or the usual name for this package manager.
    def lockfile
      @lockfile || commands.lockfiles.first
    end

    def add_command(*packages)
      [commands.add, *packages].join(" ")
    end

    def add_dev_command(*packages)
      [commands.add_dev, *packages].join(" ")
    end

    def run_command(script)
      "#{name} run #{script}"
    end

    private

    def commands
      MANAGERS.fetch(name)
    end
  end
end
