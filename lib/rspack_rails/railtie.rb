# frozen_string_literal: true

require "rails/railtie"

module RspackRails
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load File.expand_path("../tasks/rspack_rails.rake", __dir__)
    end
  end
end
