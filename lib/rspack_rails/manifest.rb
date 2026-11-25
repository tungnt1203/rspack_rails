# frozen_string_literal: true

require "json"
require "pathname"

module RspackRails
  # public/rspack/.rspack-manifest.json, which rspack.config.mjs writes
  # on every build and while `rspack serve` runs: for each entry, the scripts
  # and stylesheets to link, in order. The files carry a fingerprint in their
  # names, so the view helpers link what the manifest lists.
  #
  # `rspack serve` writes DEV_PATH instead, so a build that runs alongside it
  # (`bin/rails test` runs one) cannot replace the manifest the dev server's
  # pages need. RspackRails.manifest picks the file.
  class Manifest
    OUTPUT_DIR = "public/rspack"
    PATH = "#{OUTPUT_DIR}/.rspack-manifest.json".freeze
    DEV_PATH = "#{OUTPUT_DIR}/.rspack-dev-manifest.json".freeze

    # An entry the manifest does not list: not built yet, or not an entry.
    class MissingEntry < RspackRails::Error; end

    # A file of app/javascript/images the manifest does not list.
    class MissingAsset < RspackRails::Error; end

    # scripts: ["runtime.js", "application-3f2a9c1d.js"]; stylesheets: ["application-8b1e07aa.css"].
    # stylesheet_only: built from CSS alone (app/javascript/entrypoints/print.css);
    # it has a script only under `rspack serve`, for hot updates.
    Entry = Data.define(:scripts, :stylesheets, :stylesheet_only)

    EMPTY = { entries: {}, assets: {} }.freeze

    attr_reader :root, :path

    def initialize(root, path = PATH)
      @root = Pathname(root)
      @path = @root.join(path)
      # [mtime, entries], replaced as one object: a Puma thread never pairs a
      # new mtime with the previous entries.
      @cache = [nil, EMPTY].freeze
    end

    # The entry's files. Raises MissingEntry when rspack has not built it yet
    # (no manifest, or a new entry), and says what to run.
    def [](name)
      name = name.to_s
      entries.fetch(name) { raise MissingEntry, missing_message(name) }
    end

    # The fingerprinted file name of an image in app/javascript/images
    # ("logo.svg", "icons/menu.svg"). Raises MissingAsset when there is none.
    def asset(name)
      name = name.to_s
      assets.fetch(name) { raise MissingAsset, missing_asset_message(name) }
    end

    private

    def missing_asset_message(name)
      "rspack has no image #{name.inspect} in #{@path.relative_path_from(@root)}. " \
        "Put it in app/javascript/images/ and run bin/rails rspack:build (or restart bin/dev)" \
        "#{" (it has #{assets.keys.join(", ")})" if assets.any?}."
    end

    def missing_message(name)
      built = entries.keys
      "rspack has no entry named #{name.inspect} in #{@path.relative_path_from(@root)}" \
        "#{" (it has #{built.join(", ")})" if built.any?}. " \
        "Start the dev server with bin/dev, or run bin/rails rspack:build" \
        "#{", and restart it if #{name.inspect} is a new entry in app/javascript/entrypoints" if built.any?}."
    end

    # Re-read whenever rspack rewrites the file (each rebuild under `rspack serve`).
    # rspack does not write it atomically: a read in the middle of a write keeps
    # the last complete manifest and tries again on the next call.
    def entries = read[:entries]

    def assets = read[:assets]

    def read
      cached_mtime, cached = @cache
      mtime = @path.file? ? @path.mtime : nil
      return cached if mtime == cached_mtime

      parsed = mtime ? parse(@path.read) : EMPTY
      return cached unless parsed

      @cache = [mtime, parsed].freeze
      parsed
    end

    def parse(json)
      data = JSON.parse(json)
      entries = data.fetch("entries", {}).transform_values do |files|
        Entry.new(scripts: files.fetch("js", []), stylesheets: files.fetch("css", []),
                  stylesheet_only: files.fetch("stylesheetOnly", false))
      end
      { entries: entries, assets: data.fetch("assets", {}) }.freeze
    rescue JSON::ParserError
      nil
    end
  end
end
