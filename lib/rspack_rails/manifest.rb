# frozen_string_literal: true

require "json"
require "pathname"

module RspackRails
  # app/assets/builds/.rspack-manifest.json, which config/rspack/rails.mjs
  # writes on every build and while `rspack serve` runs: for each entry, the
  # scripts and stylesheets to link, in order. The view helpers link what it
  # lists instead of guessing file names. A dotfile, so Propshaft and Sprockets
  # leave it out of public/assets.
  class Manifest
    PATH = "app/assets/builds/.rspack-manifest.json"

    # scripts: ["runtime.js", "application.js"]; stylesheets: ["application.bundle.css"].
    # stylesheet_only: built from CSS alone (app/javascript/entrypoints/print.css);
    # it has a script only under `rspack serve`, for hot updates.
    Entry = Data.define(:scripts, :stylesheets, :stylesheet_only)

    attr_reader :root

    def initialize(root)
      @root = Pathname(root)
      @path = @root.join(PATH)
      @mtime = nil
      @entries = {}
    end

    # The entry's files, or the conventional names when rspack has not built
    # it yet (no manifest, or a new entry), so the asset pipeline can still
    # report a missing file by name.
    def [](name)
      name = name.to_s
      entries.fetch(name) do
        Entry.new(scripts: ["#{name}.js"], stylesheets: ["#{name}.bundle.css"], stylesheet_only: false)
      end
    end

    private

    # Re-read whenever rspack rewrites the file (each rebuild under `rspack serve`).
    def entries
      mtime = @path.file? ? @path.mtime : nil
      return @entries if mtime == @mtime

      @mtime = mtime
      @entries = mtime ? parse(@path.read) : {}
    end

    def parse(json)
      JSON.parse(json).fetch("entries", {}).transform_values do |files|
        Entry.new(scripts: files.fetch("js", []), stylesheets: files.fetch("css", []),
                  stylesheet_only: files.fetch("stylesheetOnly", false))
      end
    rescue JSON::ParserError
      {}
    end
  end
end
