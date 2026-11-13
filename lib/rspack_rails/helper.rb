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

    # A mount point for app/javascript/components/<name>.{jsx,tsx}, rendered
    # on the client by components/mount.js (bin/rails rspack:install:react).
    #   <%= react_component "Hello", name: "World" %>
    #   <%= react_component "Hello", { name: "World" }, html: { class: "greeting", tag: :span } %>
    def react_component(name, props = {}, html: {}, **more_props)
      html = html.dup
      tag = html.delete(:tag) || :div
      data = (html.delete(:data) || {}).merge(react_component: name, react_props: props.merge(more_props).to_json)
      content_tag(tag, "", **html, data: data)
    end
  end
end
