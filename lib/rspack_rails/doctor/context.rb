# frozen_string_literal: true

require "json"
require "open3"
require_relative "../manifest"
require_relative "../app"

module RspackRails
  class Doctor
    # What the checks read about the app, read once per doctor run and shared
    # by every group of checks.
    class Context
      attr_reader :app, :root, :config, :dev_server

      def initialize(root, config:, dev_server:, node_version:)
        @app = App.new(root)
        @root = @app.root
        @config = config
        @dev_server = dev_server
        @node_version = node_version
      end

      def node_version
        return @node_version if @node_version

        out, status = Open3.capture2("node", "--version")
        status.success? ? out.strip : nil
      rescue SystemCallError
        nil
      end

      # @rspack/<name>'s package.json in node_modules.
      def installed_package(name)
        @app.node_package("@rspack/#{name}")
      end

      def node_modules_package(name)
        @app.node_package(name)
      end

      def package_json
        @app.package_json
      end

      def layouts
        @layouts ||= @app.layouts
      end

      def layouts_including(text)
        layouts.select { |path| read(path).include?(text) }
      end

      def entrypoints
        @entrypoints ||= @app.entrypoints
      end

      def package_manager
        @package_manager ||= @app.package_manager
      end

      # The entries in public/rspack/.rspack-manifest.json, by name; empty
      # when nothing has been built.
      def built_entries
        @built_entries ||= begin
          json = read(Manifest::PATH)
          json ? JSON.parse(json).fetch("entries", {}) : {}
        rescue JSON::ParserError
          {}
        end
      end

      def exist?(path)
        @app.path(path).exist?
      end

      def read(path)
        @app.read(path)
      end
    end
  end
end
