# frozen_string_literal: true

require_relative "checks"
require_relative "../entrypoints"
require_relative "../rspack_config"

module RspackRails
  class Doctor
    # rspack.config.mjs, the package.json scripts, the entry points and what
    # rspack built from them.
    class BuildChecks < Checks
      # config/rspack/rails.mjs, by ManagedFile::BASE.state.
      BASE_STATES = {
        missing: [:error, "imports %s, which is missing", "Run `bin/rails rspack:sync`"],
        edited: [:warn, "%s has hand edits, which the next rspack:build replaces",
                 "Move them into the railsConfig callback in rspack.config.mjs"],
        outdated: [:warn, "%s is not the one from rspack_rails #{VERSION}",
                   "Run `bin/rails rspack:sync` (rspack:build does it too)"],
        current: [:ok, "uses %s from rspack_rails #{VERSION}", nil]
      }.freeze

      def checks
        [config_check, scripts_check, entry_check, build_check, legacy_output_check, gitignore_check]
      end

      private

      def config_check
        return Check.new(:error, "rspack.config.mjs", "missing", "Run `bin/rails rspack:install`") unless
          exist?("rspack.config.mjs")

        return managed_config_check if RspackConfig.managed?(root)

        Check.new(:error, RspackConfig::APP, "does not build on #{RspackConfig::BASE}",
                  "Re-run `bin/rails rspack:install`, accept the new rspack.config.mjs and move your changes " \
                  "into its railsConfig callback")
      end

      def managed_config_check
        status, detail, hint = BASE_STATES.fetch(ManagedFile::BASE.state(root))
        Check.new(status, "rspack.config.mjs", format(detail, RspackConfig::BASE), hint)
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

      # rspack_rails 1.x built into app/assets/builds. Rails 8's
      # `stylesheet_link_tag :app` would still link its stylesheets.
      def legacy_output_check
        return if Entrypoints.legacy_outputs(root).empty?

        Check.new(:warn, "Old build output", "app/assets/builds still has files from rspack_rails 1.x",
                  "Run `bin/rails rspack:clobber`, then `bin/rails rspack:build`")
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
