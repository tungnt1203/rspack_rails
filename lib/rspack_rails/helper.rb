# frozen_string_literal: true

require_relative "entrypoints"

module RspackRails
  # View helpers that load bundles from `rspack serve` when it is running
  # and fall back to the asset pipeline (app/assets/builds) otherwise.
  module Helper
    def rspack_javascript_tag(*entries, **options)
      options = { defer: true }.merge(options)
      tags = entries.map do |entry|
        source = RspackRails.dev_server.running? ? RspackRails.dev_server.url("#{entry}.js") : entry
        javascript_include_tag(source, **options)
      end
      safe_join([rspack_runtime_tag(options), *tags].compact, "\n")
    end

    # Links the CSS that rspack extracts from an entry's imports
    # (app/assets/builds/<entry>.bundle.css). Under `rspack serve`, a
    # stylesheet-only entry (app/javascript/entrypoints/print.css) also gets
    # its script, which carries the hot update client.
    def rspack_stylesheet_tag(*entries, **options)
      unless RspackRails.dev_server.running?
        return stylesheet_link_tag(*entries.map { |entry| "#{entry}.bundle" }, **options)
      end

      links = entries.map { |entry| stylesheet_link_tag(RspackRails.dev_server.url("#{entry}.bundle.css"), **options) }
      hot = entries.select { |entry| rspack_stylesheet_entry?(entry) }
      safe_join([*links, (rspack_javascript_tag(*hot) if hot.any?)].compact, "\n")
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

    private

    # Under `rspack serve` all entries share runtime.js, linked once per page.
    # Without the dev server it is linked only while app/assets/builds still
    # holds the dev server's output (a normal build removes runtime.js).
    def rspack_runtime_tag(options)
      return if @rspack_runtime_linked

      source = if RspackRails.dev_server.running?
                 RspackRails.dev_server.url("runtime.js")
               elsif rspack_root.join("app/assets/builds/runtime.js").file?
                 "runtime"
               end
      return unless source

      @rspack_runtime_linked = true
      javascript_include_tag(source, **options)
    end

    def rspack_stylesheet_entry?(entry)
      paths = Entrypoints.discover(rspack_root)[entry.to_s]
      paths ? Entrypoints.css_only?(paths) : false
    end

    def rspack_root
      defined?(::Rails.root) && ::Rails.root ? ::Rails.root : Pathname(Dir.pwd)
    end
  end
end
