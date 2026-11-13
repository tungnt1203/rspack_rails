# frozen_string_literal: true

require_relative "rspack_rails/version"
require_relative "rspack_rails/package_manager"

module RspackRails
  class Error < StandardError; end
end

require_relative "rspack_rails/railtie" if defined?(Rails::Railtie)
