# frozen_string_literal: true

require_relative "checks"
require_relative "../node_version"
require_relative "../rspack_version"

module RspackRails
  class Doctor
    # Node.js and the @rspack packages.
    class PackageChecks < Checks
      PACKAGES = %i[cli core dev-server].freeze
      NODE_MISSING = "Install Node.js and make sure `node` is on PATH"

      def checks
        [node_check, *PACKAGES.map { |name| package_check(name) }]
      end

      private

      def node_check
        version = node_version
        return Check.new(:error, "Node.js", "not found", NODE_MISSING) unless version

        required = installed_package("core")&.dig("engines", "node")
        return Check.new(:ok, "Node.js", version) unless required

        case NodeVersion.check(version, required)
        when true then Check.new(:ok, "Node.js", "#{version} (rspack needs #{required})")
        when false then Check.new(:error, "Node.js", "#{version}, but rspack needs #{required}", "Upgrade Node.js")
        else Check.new(:warn, "Node.js", "#{version}; could not read rspack's requirement #{required}")
        end
      end

      def package_check(name)
        label = "@rspack/#{name}"
        package = installed_package(name)
        return package_version_check(label, package["version"]) if package

        Check.new(name == :"dev-server" ? :warn : :error, label, "not installed", "Run `#{add_command(label)}`")
      end

      # config/rspack/rails.mjs is written for one Rspack major version.
      def package_version_check(label, version)
        major = RspackVersion::MAJOR
        case RspackVersion.compare(version)
        when :supported then Check.new(:ok, label, version)
        when :older
          Check.new(:error, label, "#{version}, but rspack_rails needs Rspack #{major}", "Run `#{add_command(label)}`")
        else
          Check.new(:warn, label, "#{version}; rspack_rails is tested with Rspack #{major}",
                    "Run `#{add_command(label)}` if the build fails")
        end
      end

      def add_command(label)
        package_manager.add_dev_command(RspackVersion.pin(label))
      end
    end
  end
end
