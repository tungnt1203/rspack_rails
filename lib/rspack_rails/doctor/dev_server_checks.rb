# frozen_string_literal: true

require_relative "checks"

module RspackRails
  class Doctor
    # Whether pages get their files from `rspack serve` right now.
    class DevServerChecks < Checks
      def checks
        [dev_server_check]
      end

      private

      def dev_server_check
        return Check.new(:ok, "Dev server", "disabled in this environment") unless config.dev_server_enabled
        return Check.new(:ok, "Dev server", "running at #{config.dev_server_url}") if dev_server.running?

        Check.new(:warn, "Dev server", "not running at #{config.dev_server_url}",
                  "Start it with bin/dev; until then pages use app/assets/builds")
      end
    end
  end
end
