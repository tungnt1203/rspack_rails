# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:tailwind`.
# Sets up Tailwind CSS v4 through @tailwindcss/webpack, and moves an app off
# tailwindcss-rails when it finds one.
pm = RspackRails::PackageManager.detect(Rails.root)
layout = "app/views/layouts/application.html.erb"
stylesheet = "app/javascript/application.css"
tailwind_rails_source = "app/assets/tailwind/application.css"
entry = %w[app/javascript/application.js app/javascript/application.ts].find { |file| File.exist?(file) }

unless File.exist?("rspack.config.mjs") && File.read("rspack.config.mjs").include?("@tailwindcss/webpack")
  say "rspack.config.mjs predates Tailwind support. Re-run `bin/rails rspack:install` and accept the new " \
      "rspack.config.mjs, then run this task again.", :red
  exit 1
end

if entry.nil?
  say "No app/javascript/application.{js,ts} found. Run `bin/rails rspack:install` first.", :red
  exit 1
end

tailwind_rails = File.exist?("Gemfile") && File.read("Gemfile").match?(/^\s*gem\s+["']tailwindcss-rails["']/)

say "Creating #{stylesheet}"
if File.exist?(tailwind_rails_source)
  # Same depth as app/javascript, so relative @source/@plugin paths still resolve.
  say "Moving #{tailwind_rails_source} (tailwindcss-rails) to #{stylesheet}"
  source = File.read(tailwind_rails_source)
  if File.exist?(stylesheet)
    prepend_to_file stylesheet, "#{source.chomp}\n\n"
  else
    create_file stylesheet, source
  end
  remove_file tailwind_rails_source
  remove_dir "app/assets/tailwind" if Dir.empty?("app/assets/tailwind")
elsif !File.exist?(stylesheet)
  create_file stylesheet, %(@import "tailwindcss";\n)
elsif !File.read(stylesheet).match?(/@import\s+["']tailwindcss["']/)
  prepend_to_file stylesheet, %(@import "tailwindcss";\n\n)
end

unless File.read(entry).match?(%r{^import ["']\./application\.css["']})
  say "Importing application.css from #{entry}"
  prepend_to_file entry, %(import "./application.css"\n)
end

if File.exist?(layout)
  content = File.read(layout)
  if content.match?(/^\s*<%= stylesheet_link_tag "tailwind".*%>\n/)
    gsub_file layout, /^\s*<%= stylesheet_link_tag "tailwind".*%>\n/, ""
  end
  unless content.include?("rspack_stylesheet_tag")
    say "Adding rspack_stylesheet_tag to #{layout}"
    insert_into_file layout, %(    <%= rspack_stylesheet_tag "application", "data-turbo-track": "reload" %>\n),
                     before: %r{^[ \t]*</head>}
  end
else
  say %(Add this to your layout: <%= rspack_stylesheet_tag "application" %>), :yellow
end

if tailwind_rails
  say "Removing tailwindcss-rails"
  gsub_file "Procfile.dev", /^css: .*tailwindcss:watch.*\n/, "" if File.exist?("Procfile.dev")
  remove_file "app/assets/builds/tailwind.css"
  remove_dir "app/assets/builds/tailwind"
  gem_line = /^[ \t]*gem[ \t]+["']tailwindcss-rails["'].*\n/
  gsub_file "Gemfile", /^[ \t]*#.*\n(?=#{gem_line.source})/, "" # the comment describing it
  gsub_file "Gemfile", gem_line, ""
  run "bundle install --quiet", abort_on_failure: true
end

if File.exist?("Gemfile") && File.read("Gemfile").match?(/^\s*gem\s+["']cssbundling-rails["']/)
  say "cssbundling-rails is still installed. If it builds Tailwind too, remove it and its build:css script, " \
      "or the CSS is built twice.", :yellow
end

say "Installing tailwindcss and @tailwindcss/webpack"
run pm.add_dev_command("tailwindcss", "@tailwindcss/webpack"), abort_on_failure: true

say "Tailwind CSS ready. Edit #{stylesheet}; classes in your views are picked up automatically.", :green
