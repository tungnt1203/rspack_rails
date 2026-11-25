# frozen_string_literal: true

require_relative "checks"
require_relative "../entrypoints"

module RspackRails
  class Doctor
    # rspack.config.mjs, the package.json scripts, the entry points and what
    # rspack built from them.
    class BuildChecks < Checks
      # What the view helpers read: written by the plugin that rspack.config.mjs gets from rspack:install.
      MANIFEST_FILE = ".rspack-manifest.json"

      def checks
        [config_check, scripts_check, entry_check, build_check, gitignore_check]
      end

      private

      def config_check
        config = read("rspack.config.mjs")
        return Check.new(:error, "rspack.config.mjs", "missing", "Run `bin/rails rspack:install`") unless config
        return Check.new(:ok, "rspack.config.mjs", "writes #{MANIFEST_FILE} for the view helpers") if
          config.include?(MANIFEST_FILE)

        Check.new(:error, "rspack.config.mjs", "does not write #{MANIFEST_FILE}, which the view helpers read",
                  "Copy the manifestPlugin and output settings from lib/install/rspack.config.mjs in the " \
                  "rspack_rails gem, or re-run `bin/rails rspack:install` and accept the new file")
      end

      def scripts_check
        scripts = package_json.fetch("scripts", {})
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

      # Nothing to build without entry points; entry_check reports that.
      def build_check
        return if entrypoints.empty?

        missing = entrypoints.keys - built_entries.keys
        return Check.new(:ok, "Build output", "public/rspack has #{entrypoints.keys.join(", ")}") if missing.empty?

        Check.new(:warn, "Build output", "not built yet: #{missing.join(", ")}",
                  "Run `bin/rails rspack:build` (only needed without the dev server)")
      end

      def gitignore_check
        gitignore = read(".gitignore")
        return if gitignore.nil? || gitignore.match?(%r{^/?public/rspack\b})

        Check.new(:warn, ".gitignore", "does not list public/rspack, where builds go",
                  "Add `/public/rspack` to .gitignore (and .dockerignore)")
      end
    end
  end
end
