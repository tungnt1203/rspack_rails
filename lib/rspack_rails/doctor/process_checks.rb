# frozen_string_literal: true

require_relative "checks"
require_relative "../containers"

module RspackRails
  class Doctor
    # Where rspack runs outside `rspack build`: bin/dev, Docker deploys and
    # dev containers.
    class ProcessChecks < Checks
      def checks
        [bin_dev_check, procfile_check, dockerfile_check, lockfile_check, devcontainer_check]
      end

      private

      # bin/dev starts Rails and the dev server together, from Procfile.dev.
      def bin_dev_check
        script = read("bin/dev")
        return Check.new(:warn, "bin/dev", "missing", "Run `bin/rails rspack:install`") unless script

        unless script.include?("Procfile.dev")
          return Check.new(:warn, "bin/dev", "does not start Procfile.dev, so the dev server is not started",
                           "Run `bin/rails rspack:install`")
        end
        return Check.new(:ok, "bin/dev", "starts Procfile.dev") if executable?("bin/dev")

        Check.new(:warn, "bin/dev", "is not executable", "Run `chmod +x bin/dev`")
      end

      # A Docker build installs node modules from the lockfile, frozen.
      def lockfile_check
        return unless read("Dockerfile")

        lockfile = package_manager.lockfile
        return Check.new(:ok, "Lockfile", lockfile) if exist?(lockfile)

        Check.new(:warn, "Lockfile", "#{lockfile} is missing, which `#{package_manager.frozen_install_command}` " \
                                     "in the Docker build needs",
                  "Run `#{package_manager.install_command}` and commit #{lockfile}")
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
