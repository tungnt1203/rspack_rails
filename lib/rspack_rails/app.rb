# frozen_string_literal: true

require "json"
require "pathname"
require_relative "entrypoints"
require_relative "layouts"
require_relative "package_manager"

module RspackRails
  # A Rails app's files as rspack_rails reads them, relative to its root:
  # package.json and installed node modules, layouts, entry points. Shared by
  # the doctor, the migration and the installers, so each reads files the
  # same way. Reads are not cached: the installers change package.json and
  # layouts while they run.
  class App
    attr_reader :root

    def initialize(root)
      @root = Pathname(root)
    end

    def path(relative)
      root.join(relative)
    end

    def file?(relative)
      path(relative).file?
    end

    # The file's content, or nil when it does not exist.
    def read(relative)
      path(relative).read if file?(relative)
    end

    # The parsed JSON file, or nil when it is missing or not valid JSON.
    def json(relative)
      content = read(relative)
      JSON.parse(content) if content
    rescue JSON::ParserError
      nil
    end

    # package.json, or {} when there is none (or it is not valid JSON).
    def package_json
      json("package.json") || {}
    end

    # The package.json of an installed node module ("@rspack/core"), or nil.
    def node_package(name)
      json("node_modules/#{name}/package.json")
    end

    def package_manager
      PackageManager.detect(root)
    end

    # Page layouts, relative to root, application.* first.
    def layouts
      Layouts.all(root)
    end

    # { "application" => ["app/javascript/application.js"], ... }
    def entrypoints
      Entrypoints.discover(root)
    end
  end
end
