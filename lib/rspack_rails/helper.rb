# frozen_string_literal: true

module RspackRails
  # View helpers that load bundles from `rspack serve` when it is running
  # and fall back to the asset pipeline (app/assets/builds) otherwise.
  module Helper
    def rspack_javascript_tag(*entries, **options)
      options = { defer: true }.merge(options)
      return javascript_include_tag(*entries, **options) unless RspackRails.dev_server.running?

      safe_join(entries.map { |entry| javascript_include_tag(RspackRails.dev_server.url("#{entry}.js"), **options) },
                "\n")
    end

    # Links the CSS that rspack extracts from an entry's imports
    # (app/assets/builds/<entry>.bundle.css).
    def rspack_stylesheet_tag(*entries, **options)
      unless RspackRails.dev_server.running?
        return stylesheet_link_tag(*entries.map { |entry| "#{entry}.bundle" }, **options)
      end

      safe_join(entries.map do |entry|
        stylesheet_link_tag(RspackRails.dev_server.url("#{entry}.bundle.css"), **options)
      end, "\n")
    end
  end
end
