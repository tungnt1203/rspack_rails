# frozen_string_literal: true

require "rails/railtie"

module RspackRails
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/rspack_rails.rake", __dir__)
    end

    initializer "rspack_rails.deprecator" do |app|
      app.deprecators[:rspack_rails] = RspackRails.deprecator
    end

    # Always installed; it only acts while the dev server is enabled.
    initializer "rspack_rails.dev_server_proxy" do |app|
      require_relative "dev_server_proxy"
      app.middleware.insert_before 0, RspackRails::DevServerProxy
    end

    # public/rspack under /rspack/, with a far-future cache header: its files
    # carry a fingerprint. Only where Rails serves public/ itself.
    initializer "rspack_rails.static_files" do |app|
      if app.config.public_file_server.enabled
        require_relative "static_files"
        app.middleware.insert_before ActionDispatch::Static, RspackRails::StaticFiles,
                                     root: app.root.join(Manifest::OUTPUT_DIR)
      end
    end

    initializer "rspack_rails.helper" do
      require_relative "helper"
      ActiveSupport.on_load(:action_view) { include RspackRails::Helper }
    end
  end
end
