# frozen_string_literal: true

require "json"
require_relative "app"
require_relative "containers"
require_relative "config_installer"
require_relative "layout_installer"
require_relative "rspack_version"

module RspackRails
  # Shared steps for the Rails application templates in lib/install. Each
  # template runs inside a Rails generator and does `extend RspackRails::Installer`,
  # so these methods can use Thor actions (say, gsub_file, insert_into_file).
  module Installer
    include ConfigInstaller
    include LayoutInstaller

    TEMPLATES = File.expand_path("../install", __dir__)

    # Runs lib/install/<name>.rb as an application template (bin/rails app:template).
    def self.run(name, task: "rspack:install:#{name}")
      template = File.join(TEMPLATES, "#{name}.rb")
      system(RbConfig.ruby, "./bin/rails", "app:template", "LOCATION=#{template}") ||
        raise(Error, "#{task} failed")
    end

    # The app being installed into. Its file access does not depend on the
    # current directory.
    def rspack_app
      App.new(destination_root)
    end

    # The app's main entry (app/javascript/application.{js,ts,jsx,tsx}), or exits
    # with a hint when there is none.
    def main_entry!
      entry = rspack_app.main_entry
      return entry if entry

      say "No app/javascript/application.{js,ts,jsx,tsx} found. Run `bin/rails rspack:install` first.", :red
      exit 1
    end

    def gem_in_gemfile?(name)
      rspack_app.read("Gemfile").to_s.match?(/^\s*gem\s+["']#{Regexp.escape(name)}["']/)
    end

    # Removes a gem from the Gemfile, along with the comment line describing it.
    def remove_gem(name)
      gem_line = /^[ \t]*gem[ \t]+["']#{Regexp.escape(name)}["'].*\n/
      gsub_file "Gemfile", /^[ \t]*#.*\n(?=#{gem_line.source})/, ""
      gsub_file "Gemfile", gem_line, ""
    end

    # Reads package.json, yields it and writes it back.
    def update_package_json
      package = JSON.parse(rspack_app.read("package.json"))
      yield package
      rspack_app.path("package.json").write("#{JSON.pretty_generate(package)}\n")
    end

    # Dockerfile (Kamal), .devcontainer and bin/setup, when the app has them.
    def configure_containers(package_manager, port:)
      edit_container_file("Dockerfile", "install Node.js and node modules in the build stage") do |content|
        Containers.add_node_to_dockerfile(content, package_manager, node_version: Containers.local_node_version)
      end
      edit_container_file(".devcontainer/devcontainer.json",
                          "add the #{Containers::NODE_FEATURE} feature and forward port #{port}") do |content|
        Containers.add_node_to_devcontainer(content, port)
      end
      edit_container_file("bin/setup", "run `#{package_manager.install_command}`") do |content|
        Containers.add_js_install_to_setup(content, package_manager)
      end
    end

    def edit_container_file(path, change)
      content = rspack_app.read(path)
      return unless content

      updated = yield content
      return say("Could not update #{path} automatically; #{change} by hand.", :yellow) unless updated
      return if updated == content

      say "Updating #{path}: #{change}"
      rspack_app.path(path).write(updated)
    end
  end
end
