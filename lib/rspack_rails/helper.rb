# frozen_string_literal: true

module RspackRails
  # View helpers that link the files RspackRails::Manifest lists for an
  # entry: from `rspack serve` when it is running, from public/rspack
  # (served by Rails under /rspack/) otherwise. They write the tags
  # themselves: rspack fingerprints its files, so no asset pipeline is
  # involved, and an app does not need Propshaft or Sprockets.
  module Helper
    ICON_TYPES = {
      "png" => "image/png", "svg" => "image/svg+xml", "ico" => "image/x-icon", "gif" => "image/gif",
      "jpg" => "image/jpeg", "jpeg" => "image/jpeg", "webp" => "image/webp", "avif" => "image/avif"
    }.freeze
    FONT_TYPES = {
      "woff2" => "font/woff2", "woff" => "font/woff", "ttf" => "font/ttf", "otf" => "font/otf"
    }.freeze

    # The entry's scripts as listed in .rspack-manifest.json (under `rspack
    # serve`, runtime.js first). A script already on the page, such as the
    # runtime shared by several entries, is linked once.
    #
    # Options become attributes of the <script> tag: `defer` (on by default),
    # `nonce: true` for the Content Security Policy nonce, `integrity: true`
    # for a Subresource Integrity hash (see docs/production.md), `data`, and so on.
    def rspack_javascript_tag(*entries, **)
      scripts = entries.flat_map { |entry| RspackRails.manifest[entry].scripts }
      rspack_script_tags(scripts, rspack_tag_options(defer: true, **))
    end

    # The CSS that rspack extracts from an entry's imports. Takes the options
    # of the <link> tag, `nonce` and `integrity` included. Under `rspack
    # serve`, a stylesheet-only entry (app/javascript/entrypoints/print.css)
    # also gets its script, which carries the hot update client (with the same
    # `nonce`, so a Content Security Policy lets it run).
    def rspack_stylesheet_tag(*entries, **options)
      entries = entries.map { |entry| RspackRails.manifest[entry] }
      links = entries.flat_map(&:stylesheets).uniq.map do |file|
        tag.link(**{ "rel" => "stylesheet" }, **rspack_attributes(file, "href", rspack_tag_options(**options)))
      end
      safe_join([*links, rspack_hot_css_scripts(entries, options)].reject(&:empty?), "\n")
    end

    # The URL of a file in app/javascript/images, fingerprinted by rspack
    # (/rspack/logo-3f2a9c1d5e6f7a8b.svg), with `config.asset_host` in front
    # when set. For `<link rel="icon">`, `<source>`, CSS in a style tag, ...
    #   <%= rspack_asset_path "icons/menu.svg" %>
    def rspack_asset_path(name)
      rspack_url(RspackRails.manifest.asset(name))
    end

    # An <img> for a file in app/javascript/images; takes the options of `tag.img`
    # (`alt`, `class`, `loading`, ...).
    #   <%= rspack_image_tag "logo.svg", alt: "Acme", class: "h-8" %>
    def rspack_image_tag(name, **options)
      tag.img(**{ "src" => rspack_asset_path(name) }, **options.stringify_keys)
    end

    # `<link rel="preload">` for an entry's scripts and stylesheets, for the
    # <head>, so the browser fetches them while it parses the page. Takes the
    # options of the tag, `nonce` and `integrity` included (the hash must match
    # the one on the script and link tags, so give both the same options).
    #   <%= rspack_preload_tag "application", integrity: true %>
    def rspack_preload_tag(*entries, **options)
      entries = entries.map { |entry| RspackRails.manifest[entry] }
      options = rspack_tag_options(**options)
      tags = rspack_preload_files(entries).map do |file, as|
        tag.link(**{ "rel" => "preload", "as" => as }, **rspack_attributes(file, "href", options))
      end
      safe_join(tags, "\n")
    end

    # `<link rel="icon">` for a file in app/javascript/images, with its `type`
    # from the extension (png, svg, ico, gif, jpg, webp, avif).
    #   <%= rspack_favicon_tag "favicon.svg" %>
    def rspack_favicon_tag(name, **options)
      type = RspackRails::Helper::ICON_TYPES[File.extname(name.to_s).delete_prefix(".").downcase]
      attributes = { "rel" => "icon", "type" => type, "href" => rspack_asset_path(name) }.compact
      tag.link(**attributes, **options.stringify_keys)
    end

    # `<link rel="preload" as="font">` for a font in app/javascript/images, so
    # the text does not flash before it loads. Fonts are fetched in anonymous
    # CORS mode, so `crossorigin` is always set.
    #   <%= rspack_font_preload_tag "fonts/inter.woff2" %>
    def rspack_font_preload_tag(name, **options)
      type = RspackRails::Helper::FONT_TYPES[File.extname(name.to_s).delete_prefix(".").downcase]
      tag.link(**{ "rel" => "preload", "as" => "font", "type" => type, "crossorigin" => "anonymous",
                   "href" => rspack_asset_path(name) }.compact, **options.stringify_keys)
    end

    private

    # [file, "script" | "style"] for each file of the entries, once. A
    # stylesheet-only entry's script (the hot update client) is not preloaded.
    def rspack_preload_files(entries)
      scripts = entries.reject(&:stylesheet_only).flat_map(&:scripts).map { |file| [file, "script"] }
      styles = entries.flat_map(&:stylesheets).map { |file| [file, "style"] }
      (scripts + styles).uniq
    end

    # Under `rspack serve`, the scripts of stylesheet-only entries; empty otherwise.
    def rspack_hot_css_scripts(entries, options)
      scripts = entries.select(&:stylesheet_only).flat_map(&:scripts)
      rspack_script_tags(scripts, rspack_tag_options(defer: true, **options.slice(:nonce, "nonce").symbolize_keys))
    end

    def rspack_script_tags(files, options)
      @rspack_linked_scripts ||= Set.new
      tags = files.select { |file| @rspack_linked_scripts.add?(file) }.map do |file|
        content_tag(:script, "", rspack_attributes(file, "src", options))
      end
      safe_join(tags, "\n")
    end

    # The dev server rewrites its files on every change, so there is nothing
    # stable to hash: no `integrity` there.
    def rspack_tag_options(**options)
      RspackRails.dev_server.running? ? options.except(:integrity, "integrity") : options
    end

    # The attributes of a tag for a file: its URL under `name` (src, href),
    # then the options, with `nonce: true` and `integrity: true` resolved.
    def rspack_attributes(file, name, options)
      attributes = { name => rspack_url(file) }.merge(options.stringify_keys)
      attributes["nonce"] = content_security_policy_nonce if attributes["nonce"] == true
      if attributes["integrity"] == true
        attributes["integrity"] = RspackRails.integrity(file)
        attributes["crossorigin"] ||= "anonymous"
      end
      attributes
    end

    # From the dev server while it runs, from public/rspack otherwise.
    # asset_path adds config.asset_host and the relative URL root.
    def rspack_url(file)
      RspackRails.dev_server.running? ? RspackRails.dev_server.url(file) : asset_path("/rspack/#{file}")
    end
  end
end
