# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:sass`.
# Sets up Sass through sass-loader and sass-embedded, and moves an app off
# dartsass-rails when it finds one.
pm = RspackRails::PackageManager.detect(Rails.root)
layout = "app/views/layouts/application.html.erb"
entry = %w[app/javascript/application.js app/javascript/application.ts].find { |file| File.exist?(file) }
dartsass_source = "app/assets/stylesheets/application.scss"

unless File.exist?("rspack.config.mjs") && File.read("rspack.config.mjs").include?("sass-loader")
  say "rspack.config.mjs predates Sass support. Re-run `bin/rails rspack:install` and accept the new " \
      "rspack.config.mjs, then run this task again.", :red
  exit 1
end

if entry.nil?
  say "No app/javascript/application.{js,ts} found. Run `bin/rails rspack:install` first.", :red
  exit 1
end

dartsass = File.exist?("Gemfile") && File.read("Gemfile").match?(/^\s*gem\s+["']dartsass-rails["']/)

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

if File.exist?(layout) && !File.read(layout).include?("rspack_stylesheet_tag")
  say "Adding rspack_stylesheet_tag to #{layout}"
  insert_into_file layout, %(    <%= rspack_stylesheet_tag "application", "data-turbo-track": "reload" %>\n),
                   before: %r{^[ \t]*</head>}
elsif !File.exist?(layout)
  say %(Add this to your layout: <%= rspack_stylesheet_tag "application" %>), :yellow
end

if dartsass
  say "Removing dartsass-rails"
  if File.exist?("config/initializers/dartsass.rb")
    say "config/initializers/dartsass.rb has custom builds. Import each of those .scss files from " \
        "JavaScript, then delete the initializer.", :yellow
  end
  gsub_file "Procfile.dev", /^css: .*dartsass:watch.*\n/, "" if File.exist?("Procfile.dev")
  remove_file "app/assets/builds/application.css"
  gem_line = /^[ \t]*gem[ \t]+["']dartsass-rails["'].*\n/
  gsub_file "Gemfile", /^[ \t]*#.*\n(?=#{gem_line.source})/, "" # the comment describing it
  gsub_file "Gemfile", gem_line, ""
  run "bundle install --quiet", abort_on_failure: true
end

say "Installing sass-loader and sass-embedded"
run pm.add_dev_command("sass-loader", "sass-embedded"), abort_on_failure: true

say "Sass ready. Import .scss files from JavaScript; they are bundled into application.bundle.css.", :green
