# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:migrate`.
# Moves an app from importmap-rails or jsbundling-rails to rspack_rails.
require "rspack_rails/installer"
require "rspack_rails/migration"
extend RspackRails::Installer

migration = RspackRails::Migration.new(Rails.root)
pm = RspackRails::PackageManager.detect(Rails.root)

case migration.source
when :rspack
  say "This app already uses rspack_rails. Run `bin/rails rspack:doctor` to check it.", :green
  exit
when :shakapacker
  say "Shakapacker/Webpacker apps are not supported by rspack:migrate yet.", :red
  exit 1
when :none
  say "No importmap-rails or jsbundling-rails setup found. Running rspack:install instead."
when :importmap
  say "Migrating from importmap-rails"
  packages = migration.npm_install_args
  vendored = migration.vendored_files

  # In place, in every layout and layout partial that had it (an admin layout too).
  replace_in_layouts "javascript_importmap_tags", %(rspack_javascript_tag "application", "data-turbo-track": "reload")
  if File.exist?("app/assets/config/manifest.js")
    gsub_file "app/assets/config/manifest.js", %r{^//= link_tree \.\./\.\./javascript .js\n}, ""
    gsub_file "app/assets/config/manifest.js", %r{^//= link_tree \.\./\.\./\.\./vendor/javascript .js\n}, ""
  end
  if File.exist?("app/javascript/application.js")
    gsub_file "app/javascript/application.js", %r{^// Configure your import map in config/importmap.rb.*\n}, ""
  end
  Dir.glob("app/controllers/**/*.rb").each do |controller|
    next unless File.read(controller).include?("stale_when_importmap_changes")

    gsub_file controller, /^[ \t]*# Changes to the importmap will invalidate the etag.*\n/, ""
    gsub_file controller, /^[ \t]*stale_when_importmap_changes.*\n/, ""
  end
  gsub_file "config/ci.rb", %r{^[ \t]*step .*bin/importmap audit.*\n}, "" if File.exist?("config/ci.rb")
  remove_file "config/importmap.rb"
  remove_file "bin/importmap"
  vendored.each { |path| remove_file path }
  remove_gem "importmap-rails"
when :jsbundling
  say "Migrating from jsbundling-rails"
  bundlers = migration.bundler_packages
  migration.bundler_configs.each { |path| remove_file path }
  gsub_file "Procfile.dev", /^js: .*\n/, "js: #{pm.run_command("dev")}\n" if File.exist?("Procfile.dev")
  remove_gem "jsbundling-rails"
end

@rspack_migrating = true
apply "#{__dir__}/install.rb"

if migration.source == :importmap && packages.any?
  say "Installing packages that were pinned in config/importmap.rb: #{packages.join(", ")}"
  run pm.add_command(*packages), abort_on_failure: true
end

if migration.source == :jsbundling && bundlers.any?
  say "Removing the previous bundler: #{bundlers.join(", ")}"
  update_package_json do |package|
    bundlers.each do |name|
      package["dependencies"]&.delete(name)
      package["devDependencies"]&.delete(name)
    end
  end
end

# stimulus-loading exists only with importmap: register the controllers through Rspack instead.
controllers_index = "app/javascript/controllers/index.js"
if migration.source == :importmap && File.exist?(controllers_index) &&
   File.read(controllers_index).include?("@hotwired/stimulus-loading")
  say "Registering Stimulus controllers through Rspack in #{controllers_index}"
  create_file controllers_index, File.read("#{__dir__}/controllers_index.js"), force: true
end

if migration.source == :jsbundling
  migration.extra_root_entries.each do |path|
    say "#{path} was an entry point under jsbundling. Move it to app/javascript/entrypoints/ " \
        "so rspack builds it.", :yellow
  end
end

leftovers = Dir.glob("{app,config,lib}/**/*.{rb,erb,js,ts,yml}").flat_map do |path|
  File.readlines(path).each_with_index.filter_map do |line, index|
    next if line.strip.start_with?("#", "//", "<%#")

    "#{path}:#{index + 1}: #{line.strip}" if line.match?(/importmap|jsbundling/i)
  end
end
if leftovers.any?
  say "These lines still mention importmap/jsbundling and may need a manual change:", :yellow
  leftovers.each { |line| say "  #{line}", :yellow }
end

unless ENV["RSPACK_TEMPLATE"] # template.rb has more steps, and its own closing message
  say "Migration finished. Review the changes with `git diff`, then run `bin/rails rspack:doctor`.", :green
end
