# frozen_string_literal: true

require "json"
require "open3"
require "pathname"
require_relative "node_version"
require_relative "entrypoints"

module RspackRails
  # Inspects a Rails app's rspack setup and reports what is missing.
  class Doctor
    Check = Struct.new(:status, :name, :detail, :hint)
    LAYOUT = "app/views/layouts/application.html.erb"
    SYMBOLS = { ok: "✓", warn: "!", error: "✗" }.freeze

    def initialize(root, config: RspackRails.config, dev_server: RspackRails.dev_server, node_version: nil)
      @root = Pathname(root)
      @config = config
      @dev_server = dev_server
      @node_version = node_version
    end

    def checks
      @checks ||= [
        node_check, package_check(:cli), package_check(:core), package_check(:"dev-server"),
        config_check, scripts_check, entry_check, build_check, layout_check, stylesheet_check, procfile_check,
        stimulus_check, dev_server_check
      ].compact
    end

    def ok?
      checks.none? { |check| check.status == :error }
    end

    def report(io = $stdout)
      checks.each do |check|
        io.puts "#{SYMBOLS.fetch(check.status)} #{check.name}: #{check.detail}"
        io.puts "    → #{check.hint}" if check.hint && check.status != :ok
      end
      io.puts
      io.puts summary
    end

    def summary
      errors = checks.count { |c| c.status == :error }
      warnings = checks.count { |c| c.status == :warn }
      return "Everything looks good." if errors.zero? && warnings.zero?

      "#{errors} error(s), #{warnings} warning(s)."
    end

    private

    def node_check
      version = node_version
      return Check.new(:error, "Node.js", "not found", "Install Node.js and make sure `node` is on PATH") unless version

      required = installed_package("core")&.dig("engines", "node")
      return Check.new(:ok, "Node.js", version) unless required

      case NodeVersion.check(version, required)
      when true then Check.new(:ok, "Node.js", "#{version} (rspack needs #{required})")
      when false then Check.new(:error, "Node.js", "#{version}, but rspack needs #{required}", "Upgrade Node.js")
      else Check.new(:warn, "Node.js", "#{version}; could not read rspack's requirement #{required}")
      end
    end

    def package_check(name)
      package = installed_package(name)
      label = "@rspack/#{name}"
      if package
        Check.new(:ok, label, package["version"])
      else
        Check.new(name == :"dev-server" ? :warn : :error, label, "not installed",
                  "Run `#{package_manager.add_dev_command(label)}`")
      end
    end

    def config_check
      return Check.new(:error, "rspack.config.mjs", "missing", "Run `bin/rails rspack:install`") unless
        exist?("rspack.config.mjs")

      # Generated before 0.7.1: rspack serve hands out http://localhost:3036/ URLs.
      unless read("rspack.config.mjs").include?('"/rspack/"')
        return Check.new(:warn, "rspack.config.mjs", "loads chunks and workers from the dev server's origin",
                         "Re-run `bin/rails rspack:install` and accept the new rspack.config.mjs " \
                         "(Web Workers fail under rspack serve otherwise)")
      end

      Check.new(:ok, "rspack.config.mjs", "found")
    end

    def scripts_check
      scripts = package_json&.fetch("scripts", {}) || {}
      missing = %w[build dev].reject { |name| scripts.key?(name) }
      return Check.new(:ok, "package.json scripts", "build, dev") if missing.empty?

      Check.new(missing.include?("build") ? :error : :warn, "package.json scripts",
                "missing #{missing.join(", ")}", "Run `bin/rails rspack:install`")
    end

    def entry_check
      return Check.new(:ok, "Entry points", entrypoints.keys.join(", ")) if entrypoints.any?

      Check.new(:error, "Entry points", "none found",
                "Create app/javascript/application.js or a file in app/javascript/entrypoints/")
    end

    def build_check
      missing = entrypoints.reject do |name, paths|
        exist?("app/assets/builds/#{name}#{Entrypoints.css_only?(paths) ? ".bundle.css" : ".js"}")
      end.keys
      return Check.new(:ok, "Build output", "app/assets/builds has #{entrypoints.keys.join(", ")}") if missing.empty?

      Check.new(:warn, "Build output", "not built yet: #{missing.join(", ")}",
                "Run `bin/rails rspack:build` (only needed without the dev server)")
    end

    def layout_check
      layout = read(LAYOUT)
      return Check.new(:warn, "Layout", "app/views/layouts/application.html.erb not found") unless layout

      if layout.include?("javascript_importmap_tags")
        return Check.new(:warn, "Layout", "still includes javascript_importmap_tags",
                         "Remove it if rspack replaces importmap, or the app may load JavaScript twice")
      end
      return Check.new(:ok, "Layout", "uses rspack_javascript_tag") if layout.include?("rspack_javascript_tag")

      Check.new(:warn, "Layout", "does not use rspack_javascript_tag",
                %(Add <%= rspack_javascript_tag "application" %> to get the dev server and HMR))
    end

    def stylesheet_check
      return unless exist?("app/assets/builds/application.bundle.css")

      linked = read(LAYOUT)&.include?("rspack_stylesheet_tag")
      return Check.new(:ok, "Stylesheet", "uses rspack_stylesheet_tag") if linked

      Check.new(:warn, "Stylesheet", "application.bundle.css is built but not linked",
                %(Add <%= rspack_stylesheet_tag "application" %> to your layout))
    end

    def procfile_check
      procfile = read("Procfile.dev")
      if procfile&.match?(/^js: .*\bdev$/)
        Check.new(:ok, "Procfile.dev", "runs the dev server")
      elsif procfile&.match?(/^js:/)
        Check.new(:warn, "Procfile.dev", "js process does not run `dev`",
                  "Use `js: #{package_manager.run_command("dev")}` for HMR")
      else
        Check.new(:warn, "Procfile.dev", "no js process", "Run `bin/rails rspack:install`")
      end
    end

    def stimulus_check
      return unless exist?("app/javascript/controllers/autoload.js")

      if node_modules_package("@hotwired/stimulus")
        Check.new(:ok, "Stimulus", "autoload enabled")
      else
        Check.new(:error, "Stimulus", "@hotwired/stimulus is not installed",
                  "Run `#{package_manager.add_command("@hotwired/stimulus")}`")
      end
    end

    def dev_server_check
      return Check.new(:ok, "Dev server", "disabled in this environment") unless @config.dev_server_enabled
      return Check.new(:ok, "Dev server", "running at #{@config.dev_server_url}") if @dev_server.running?

      Check.new(:warn, "Dev server", "not running at #{@config.dev_server_url}",
                "Start it with bin/dev; until then pages use app/assets/builds")
    end

    def node_version
      return @node_version if @node_version

      out, status = Open3.capture2("node", "--version")
      status.success? ? out.strip : nil
    rescue SystemCallError
      nil
    end

    def installed_package(name)
      node_modules_package("@rspack/#{name}")
    end

    def node_modules_package(name)
      path = @root.join("node_modules", name, "package.json")
      JSON.parse(path.read) if path.exist?
    rescue JSON::ParserError
      nil
    end

    def package_json
      JSON.parse(read("package.json")) if exist?("package.json")
    rescue JSON::ParserError
      nil
    end

    def entrypoints
      @entrypoints ||= Entrypoints.discover(@root)
    end

    def package_manager
      @package_manager ||= PackageManager.detect(@root)
    end

    def exist?(path)
      @root.join(path).exist?
    end

    def read(path)
      file = @root.join(path)
      file.read if file.exist?
    end
  end
end
