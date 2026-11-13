# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:stimulus`.
pm = RspackRails::PackageManager.detect(Rails.root)
entry = RspackRails::Entrypoints.main_entry(Rails.root)
controllers_import = %r{^import ["'](?:\./)?controllers(/index(\.js)?)?["'];?$}

say "Installing Stimulus with controller autoloading"
unless File.exist?("app/javascript/controllers/application.js")
  copy_file "#{__dir__}/stimulus/application.js", "app/javascript/controllers/application.js"
end
copy_file "#{__dir__}/stimulus/autoload.js", "app/javascript/controllers/autoload.js"

if Dir.glob("app/javascript/controllers/**/*_controller.{js,ts}").empty?
  copy_file "#{__dir__}/stimulus/hello_controller.js", "app/javascript/controllers/hello_controller.js"
end

if entry.nil?
  create_file "app/javascript/application.js", %(import "./controllers/autoload"\n)
elsif File.read(entry).match?(controllers_import)
  say "Replacing the controllers import with controllers/autoload"
  gsub_file entry, controllers_import, %(import "./controllers/autoload")
elsif !File.read(entry).include?("./controllers/autoload")
  append_to_file entry, %(import "./controllers/autoload"\n)
end

if File.exist?("app/javascript/controllers/index.js")
  say "app/javascript/controllers/index.js is no longer imported; controllers/autoload.js replaces it.", :yellow
end

say "Installing @hotwired/stimulus"
run pm.add_command("@hotwired/stimulus"), abort_on_failure: true

say "Stimulus installed. Controllers in app/javascript/controllers are registered automatically.", :green
