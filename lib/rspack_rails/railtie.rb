# frozen_string_literal: true

require "rails/railtie"

module RspackRails
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/rspack_rails.rake", __dir__)
    end

    # Always installed; it only acts while the dev server is enabled.
    initializer "rspack_rails.dev_server_proxy" do |app|
      require_relative "dev_server_proxy"
      app.middleware.insert_before 0, RspackRails::DevServerProxy
    end

    initializer "rspack_rails.helper" do
      require_relative "helper"
      ActiveSupport.on_load(:action_view) { include RspackRails::Helper }
    end
  end
end
