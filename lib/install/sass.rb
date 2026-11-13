# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:sass`.
# Sets up Sass through sass-loader and sass-embedded, and moves an app off
# dartsass-rails when it finds one.
require "rspack_rails/installer"
extend RspackRails::Installer

pm = RspackRails::PackageManager.detect(Rails.root)
dartsass_source = "app/assets/stylesheets/application.scss"

require_config! "sass-loader", "Sass"
entry = main_entry!
dartsass = gem_in_gemfile?("dartsass-rails")

stylesheet =
  if File.exist?(dartsass_source)
    # Imported where it is, so its relative @use/@import paths keep working.
    say "Building #{dartsass_source} with rspack"
    "../assets/stylesheets/application.scss"
  else
    unless File.exist?("app/javascript/application.scss")
      create_file "app/javascript/application.scss", <<~SCSS
        // Sass entry, imported from #{File.basename(entry)}. Partials in
        // app/assets/stylesheets can be loaded with @use "name".
        $accent: rebeccapurple;

        body {
          accent-color: $accent;
        }
      SCSS
    end
    "./application.scss"
  end

unless File.read(entry).include?(%("#{stylesheet}"))
  say "Importing #{stylesheet} from #{entry}"
  prepend_to_file entry, %(import "#{stylesheet}"\n)
end

# Sprockets compiles .scss files under app/assets/stylesheets itself (through
# `require_tree .` and `link_directory`), which needs the sassc gem.
if File.exist?("app/assets/config/manifest.js") && !File.exist?(dartsass_source)
  say "This app uses Sprockets, which compiles any .scss file under app/assets/stylesheets with the sassc " \
      "gem. Keep Sass files in app/javascript, e.g. app/javascript/stylesheets/_variables.scss loaded " \
      "with @use \"stylesheets/variables\".", :yellow
end

add_stylesheet_tag

if dartsass
  say "Removing dartsass-rails"
  if File.exist?("config/initializers/dartsass.rb")
    say "config/initializers/dartsass.rb has custom builds. Import each of those .scss files from " \
        "JavaScript, then delete the initializer.", :yellow
  end
  gsub_file "Procfile.dev", /^css: .*dartsass:watch.*\n/, "" if File.exist?("Procfile.dev")
  remove_file "app/assets/builds/application.css"
  remove_gem "dartsass-rails"
  run "bundle install --quiet", abort_on_failure: true
end

say "Installing sass-loader and sass-embedded"
run pm.add_dev_command("sass-loader", "sass-embedded"), abort_on_failure: true

say "Sass ready. Import .scss files from JavaScript; they are bundled into application.bundle.css.", :green
