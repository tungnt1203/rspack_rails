# frozen_string_literal: true

require_relative "checks"
require_relative "../containers"
require_relative "../tailwind"

module RspackRails
  class Doctor
    # Where rspack runs outside `rspack build`: bin/dev, Docker deploys and
    # dev containers.
    class ProcessChecks < Checks
      def checks
        [procfile_check, dockerfile_check, tailwind_check, devcontainer_check]
      end

      private

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

      # Kamal and other Docker deploys run assets:precompile, which runs rspack.
      def dockerfile_check
        dockerfile = read("Dockerfile")
        return unless dockerfile
        return Check.new(:ok, "Dockerfile", "installs Node.js and node modules") if
          Containers.dockerfile_ready?(dockerfile)

        Check.new(:error, "Dockerfile", "does not install Node.js and node modules; assets:precompile will fail",
                  "Re-run `bin/rails rspack:install`, or install Node.js and run " \
                  "`#{package_manager.frozen_install_command}` in the build stage")
      end

      # A Docker build has no .gitignore, so Tailwind scans tmp/ (bootsnap's
      # cache) unless the stylesheet leaves it out.
      def tailwind_check
        css = read(Tailwind::STYLESHEET)
        return unless css && exist?("Dockerfile") && Tailwind.imports_tailwind?(css)
        return Check.new(:ok, "Tailwind CSS", "leaves tmp, log, storage and public/rspack out of its scan") if
          Tailwind.excludes?(css)

        Check.new(:warn, "Tailwind CSS", "scans tmp/ in a Docker build, which has no .gitignore: " \
                                         "unused classes end up in the production CSS",
                  "Re-run `bin/rails rspack:install:tailwind`, which adds `@source not` lines " \
                  "to #{Tailwind::STYLESHEET}")
      end

      def devcontainer_check
        devcontainer = read(".devcontainer/devcontainer.json")
        return unless devcontainer

        port = config.dev_server_port
        return Check.new(:ok, "Dev container", "has Node.js and forwards #{port}") if
          Containers.devcontainer_ready?(devcontainer, port)

        Check.new(:warn, "Dev container", "needs Node.js and port #{port} forwarded for the dev server",
                  "Re-run `bin/rails rspack:install`")
      end
    end
  end
end
