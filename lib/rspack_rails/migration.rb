# frozen_string_literal: true

require "json"
require "pathname"

module RspackRails
  # Detects how an app bundles JavaScript today and works out what
  # `rspack:migrate` has to change. Pure inspection: nothing here writes files.
  class Migration
    Pin = Struct.new(:name, :to, :version, keyword_init: true)

    # importmap-only helpers with no npm equivalent.
    IMPORTMAP_ONLY = %w[@hotwired/stimulus-loading].freeze

    BUNDLER_PACKAGES = %w[esbuild webpack webpack-cli rollup @rollup/plugin-node-resolve
                          @rollup/plugin-commonjs @rollup/plugin-terser].freeze
    BUNDLER_CONFIGS = %w[webpack.config.js rollup.config.js rollup.config.mjs].freeze

    attr_reader :root

    def initialize(root)
      @root = Pathname(root)
    end

    # :rspack, :shakapacker, :importmap, :jsbundling or :none
    def source
      @source ||= if file?("rspack.config.mjs") then :rspack
                  elsif file?("config/shakapacker.yml") || file?("config/webpacker.yml") then :shakapacker
                  elsif file?("config/importmap.rb") then :importmap
                  elsif jsbundling? then :jsbundling
                  else
                    :none
                  end
    end

    def pins
      @pins ||= parse_pins(read("config/importmap.rb").to_s)
    end

    # { "package" => "version or nil" } for every pin that comes from npm. The version is
    # known only when importmap recorded it (vendored "# @1.2.3" pins or jspm URLs); gem-served
    # pins such as turbo-rails install the latest npm release.
    def npm_packages
      pins.reject { |pin| local_pin?(pin) || IMPORTMAP_ONLY.include?(pin.name) }
          .to_h { |pin| [package_name(pin.name), pin.version] }
    end

    # The argument list for `npm install` / `yarn add`, versions pinned when known.
    def npm_install_args
      npm_packages.map { |name, version| version ? "#{name}@#{version}" : name }
    end

    # Vendored copies of packages that now come from npm.
    def vendored_files
      pins.reject { |pin| local_pin?(pin) }.filter_map do |pin|
        path = "vendor/javascript/#{pin.to || "#{pin.name}.js"}"
        path if file?(path)
      end
    end

    def bundler_packages
      dev = package_json.fetch("devDependencies", {}).keys + package_json.fetch("dependencies", {}).keys
      dev & BUNDLER_PACKAGES
    end

    def bundler_configs
      BUNDLER_CONFIGS.select { |path| file?(path) }
    end

    # jsbundling's esbuild default builds every file in app/javascript; rspack
    # only builds application.* and entrypoints/*.
    def extra_root_entries
      Dir.glob("app/javascript/*.{js,ts}", base: root).sort.grep_v(%r{/application\.[jt]s\z})
    end

    def parse_pins(source)
      source.each_line.filter_map do |line|
        match = line.match(/^\s*pin\s+["']([^"']+)["'](.*)$/)
        next unless match

        rest = match[2]
        to = rest[/to:\s*["']([^"']+)["']/, 1]
        version = rest[/#\s*@(\S+)/, 1] || to.to_s[%r{npm:(?:@[^/]+/)?[^@/]+@([^/]+)/}, 1]
        Pin.new(name: match[1], to: to, version: version)
      end
    end

    private

    def jsbundling?
      read("Gemfile").to_s.match?(/^\s*gem\s+["']jsbundling-rails["']/) ||
        package_json.dig("scripts", "build").to_s.match?(/\b(esbuild|webpack|rollup|bun build)\b/)
    end

    # A pin is app code when it, or the file it points to, lives in app/javascript.
    def local_pin?(pin)
      return true if pin.name == "application"

      target = pin.to || "#{pin.name}.js"
      return false if target.match?(%r{\Ahttps?://})

      file?("app/javascript/#{target}")
    end

    # "@rails/actioncable/src" -> "@rails/actioncable", "lodash/debounce" -> "lodash"
    def package_name(specifier)
      parts = specifier.split("/")
      specifier.start_with?("@") ? parts.first(2).join("/") : parts.first
    end

    def package_json
      @package_json ||= file?("package.json") ? JSON.parse(read("package.json")) : {}
    rescue JSON::ParserError
      @package_json = {}
    end

    def file?(path)
      root.join(path).file?
    end

    def read(path)
      root.join(path).read if file?(path)
    end
  end
end
