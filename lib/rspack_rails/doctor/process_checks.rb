# frozen_string_literal: true

require_relative "checks"
require_relative "../containers"

module RspackRails
  class Doctor
    # Where rspack runs outside `rspack build`: bin/dev, Docker deploys and
    # dev containers.
    class ProcessChecks < Checks
      def checks
        [procfile_check, dockerfile_check, devcontainer_check]
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
