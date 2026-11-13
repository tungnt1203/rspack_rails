# frozen_string_literal: true

require "pathname"

module RspackRails
  # Mirrors the entry discovery in the generated rspack.config.mjs:
  # app/javascript/application.{js,ts} plus every
  # app/javascript/entrypoints/*.{js,ts}, named after the file.
  module Entrypoints
    EXTENSIONS = %w[js ts].freeze

    module_function

    # => { "application" => "app/javascript/application.js", "admin" => "app/javascript/entrypoints/admin.js" }
    def discover(root)
      root = Pathname(root)
      entries = {}
      main = EXTENSIONS.map { |ext| "app/javascript/application.#{ext}" }.find { |path| root.join(path).file? }
      entries["application"] = main if main

      Dir.glob("app/javascript/entrypoints/*.{#{EXTENSIONS.join(",")}}", base: root).sort.each do |path|
        entries[File.basename(path, ".*")] = path
      end
      entries
    end
  end
end
