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

    attr_reader :root, :name

    def self.detect(root = Dir.pwd)
      new(root)
    end

    def initialize(root)
      @root = root.to_s
      @name = LOCKFILES.find { |_, files| files.any? { |f| File.exist?(File.join(@root, f)) } }&.first || :npm
    end

    def install_command
      INSTALL.fetch(name)
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
