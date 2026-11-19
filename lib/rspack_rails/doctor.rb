# frozen_string_literal: true

require_relative "doctor/context"
require_relative "doctor/package_checks"
require_relative "doctor/build_checks"
require_relative "doctor/layout_checks"
require_relative "doctor/process_checks"
require_relative "doctor/loader_checks"
require_relative "doctor/dev_server_checks"

module RspackRails
  # Inspects a Rails app's rspack setup and reports what is missing. The checks
  # live in groups under lib/rspack_rails/doctor/, which share one Context.
  class Doctor
    Check = Struct.new(:status, :name, :detail, :hint)
    SYMBOLS = { ok: "✓", warn: "!", error: "✗" }.freeze
    # In report order.
    GROUPS = [PackageChecks, BuildChecks, LayoutChecks, ProcessChecks, LoaderChecks, DevServerChecks].freeze

    def initialize(root, config: RspackRails.config, dev_server: RspackRails.dev_server, node_version: nil)
      @context = Context.new(root, config: config, dev_server: dev_server, node_version: node_version)
    end

    def checks
      @checks ||= GROUPS.flat_map { |group| group.new(@context).checks }.compact
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
  end
end
