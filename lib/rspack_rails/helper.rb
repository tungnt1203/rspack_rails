# frozen_string_literal: true

module RspackRails
  # View helpers that link the files RspackRails::Manifest lists for an
  # entry: from `rspack serve` when it is running, from the asset pipeline
  # (app/assets/builds) otherwise.
  module Helper
    # The entry's scripts as listed in .rspack-manifest.json (under `rspack
    # serve`, runtime.js first). A script already on the page, such as the
    # runtime shared by several entries, is linked once.
    #
    # Both tag helpers take the options of javascript_include_tag and
    # stylesheet_link_tag, including `integrity: true` (see docs/production.md).
    def rspack_javascript_tag(*entries, **)
      scripts = entries.flat_map { |entry| RspackRails.manifest[entry].scripts }
      rspack_script_tags(scripts, rspack_tag_options(defer: true, **))
    end

    # The CSS that rspack extracts from an entry's imports
    # (app/assets/builds/<entry>.bundle.css). Under `rspack serve`, a
    # stylesheet-only entry (app/javascript/entrypoints/print.css) also gets
    # its script, which carries the hot update client.
    def rspack_stylesheet_tag(*entries, **options)
      entries = entries.map { |entry| RspackRails.manifest[entry] }
      links = entries.flat_map(&:stylesheets).uniq.map do |file|
        stylesheet_link_tag(rspack_source(file), **rspack_tag_options(**options))
      end
      hot = rspack_script_tags(entries.select(&:stylesheet_only).flat_map(&:scripts), rspack_tag_options(defer: true))
      safe_join([*links, hot].reject(&:empty?), "\n")
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

    def rspack_script_tags(files, options)
      @rspack_linked_scripts ||= Set.new
      tags = files.select { |file| @rspack_linked_scripts.add?(file) }
                  .map { |file| javascript_include_tag(rspack_source(file), **options) }
      safe_join(tags, "\n")
    end

    # The dev server rewrites its files on every change and is not part of the
    # asset pipeline, which computes integrity hashes: no `integrity` there.
    def rspack_tag_options(**options)
      RspackRails.dev_server.running? ? options.except(:integrity, "integrity") : options
    end

    # From the dev server while it runs, from the asset pipeline otherwise.
    def rspack_source(file)
      RspackRails.dev_server.running? ? RspackRails.dev_server.url(file) : file
    end
  end
end
