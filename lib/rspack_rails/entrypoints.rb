# frozen_string_literal: true

require "pathname"

module RspackRails
  # Mirrors the entry discovery in the generated rspack.config.mjs:
  # app/javascript/application.{js,ts,jsx,tsx} plus every
  # app/javascript/entrypoints/*.{js,ts,jsx,tsx,css,scss,sass}, named after the
  # file. admin.js and admin.css side by side make one entry.
  module Entrypoints
    SCRIPT_EXTENSIONS = %w[js ts jsx tsx].freeze
    STYLE_EXTENSIONS = %w[css scss sass].freeze

    module_function

    # => { "application" => ["app/javascript/application.js"],
    #      "print" => ["app/javascript/entrypoints/print.css"] }
    def discover(root)
      root = Pathname(root)
      entries = {}
      main = main_entry(root)
      entries["application"] = [main] if main

      extensions = (SCRIPT_EXTENSIONS + STYLE_EXTENSIONS).join(",")
      Dir.glob("app/javascript/entrypoints/*.{#{extensions}}", base: root).sort.each do |path|
        (entries[File.basename(path, ".*")] ||= []) << path
      end
      entries
    end

    def main_entry(root)
      SCRIPT_EXTENSIONS.map { |ext| "app/javascript/application.#{ext}" }.find { |path| root.join(path).file? }
    end

    # A stylesheet-only entry builds <name>.bundle.css and no <name>.js
    # (except under `rspack serve`, which adds its HMR client).
    def css_only?(paths)
      paths.all? { |path| STYLE_EXTENSIONS.include?(File.extname(path).delete_prefix(".")) }
    end
  end
end
