# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:tailwind`.
# Sets up Tailwind CSS v4 through @tailwindcss/webpack, and moves an app off
# tailwindcss-rails when it finds one.
require "rspack_rails/installer"
extend RspackRails::Installer

pm = RspackRails::PackageManager.detect(Rails.root)
stylesheet = "app/javascript/application.css"
tailwind_rails_source = "app/assets/tailwind/application.css"

require_config! "@tailwindcss/webpack", "Tailwind"
entry = main_entry!
tailwind_rails = gem_in_gemfile?("tailwindcss-rails")

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

remove_from_layouts 'stylesheet_link_tag[ (]"tailwind"'
add_stylesheet_tag

if tailwind_rails
  say "Removing tailwindcss-rails"
  gsub_file "Procfile.dev", /^css: .*tailwindcss:watch.*\n/, "" if File.exist?("Procfile.dev")
  remove_file "app/assets/builds/tailwind.css"
  remove_dir "app/assets/builds/tailwind"
  remove_gem "tailwindcss-rails"
  run "bundle install --quiet", abort_on_failure: true
end

if gem_in_gemfile?("cssbundling-rails")
  say "cssbundling-rails is still installed. If it builds Tailwind too, remove it and its build:css script, " \
      "or the CSS is built twice.", :yellow
end

say "Installing tailwindcss and @tailwindcss/webpack"
run pm.add_dev_command("tailwindcss", "@tailwindcss/webpack"), abort_on_failure: true

say "Tailwind CSS ready. Edit #{stylesheet}; classes in your views are picked up automatically.", :green
