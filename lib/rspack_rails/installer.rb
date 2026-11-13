# frozen_string_literal: true

require "json"
require_relative "entrypoints"
require_relative "layouts"

module RspackRails
  # Shared steps for the Rails application templates in lib/install. Each
  # template runs inside a Rails generator and does `extend RspackRails::Installer`,
  # so these methods can use Thor actions (say, gsub_file, insert_into_file).
  module Installer
    TEMPLATES = File.expand_path("../install", __dir__)

    # Runs lib/install/<name>.rb as an application template (bin/rails app:template).
    def self.run(name, task: "rspack:install:#{name}")
      template = File.join(TEMPLATES, "#{name}.rb")
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(Error, "#{task} failed")
    end

    # The app's main entry (app/javascript/application.{js,ts,jsx,tsx}), or exits
    # with a hint when there is none.
    def main_entry!
      entry = Entrypoints.main_entry(Pathname(destination_root))
      return entry if entry

      say "No app/javascript/application.{js,ts,jsx,tsx} found. Run `bin/rails rspack:install` first.", :red
      exit 1
    end

    # Exits unless rspack.config.mjs mentions `marker`, i.e. it is recent enough
    # for the feature being installed.
    def require_config!(marker, feature)
      return if File.exist?("rspack.config.mjs") && File.read("rspack.config.mjs").include?(marker)

      say "rspack.config.mjs predates #{feature} support. Re-run `bin/rails rspack:install` and accept the new " \
          "rspack.config.mjs, then run this task again.", :red
      exit 1
    end

    def gem_in_gemfile?(name)
      File.exist?("Gemfile") && File.read("Gemfile").match?(/^\s*gem\s+["']#{Regexp.escape(name)}["']/)
    end

    # Removes a gem from the Gemfile, along with the comment line describing it.
    def remove_gem(name)
      gem_line = /^[ \t]*gem[ \t]+["']#{Regexp.escape(name)}["'].*\n/
      gsub_file "Gemfile", /^[ \t]*#.*\n(?=#{gem_line.source})/, ""
      gsub_file "Gemfile", gem_line, ""
    end

    # Reads package.json, yields it and writes it back.
    def update_package_json
      package = JSON.parse(File.read("package.json"))
      yield package
      File.write("package.json", "#{JSON.pretty_generate(package)}\n")
    end

    # app/views/layouts/application.html.{erb,slim,haml}, or nil.
    def layout
      Layouts.main(destination_root)
    end

    # Adds `code` (a helper call) to the end of <head> in the application
    # layout, unless the layout already mentions `marker`.
    def add_to_layout(code, marker:)
      path = layout
      return say("Add this to your layout: <%= #{code} %>", :yellow) unless path

      content = File.read(path)
      return if content.include?(marker)

      updated = Layouts.insert_in_head(path, content, code)
      return say("Add this to the <head> of #{path}: #{Layouts.tag(path, code)}", :yellow) unless updated

      say "Adding #{marker} to #{path}"
      File.write(path, updated)
    end

    def add_stylesheet_tag
      add_to_layout(%(rspack_stylesheet_tag "application", "data-turbo-track": "reload"),
                    marker: "rspack_stylesheet_tag")
    end

    # Removes lines that call `helper` (ERB, Slim or Haml) from every layout.
    def remove_from_layouts(helper)
      Layouts.all(destination_root).each do |path|
        gsub_file path, /^[ \t]*(?:<%=|=)[ \t]*#{helper}(?!\w).*\n/, ""
      end
    end
  end
end
