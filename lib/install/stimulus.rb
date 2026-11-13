# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:stimulus`.
pm = RspackRails::PackageManager.detect(Rails.root)
entry = "app/javascript/application.js"

say "Installing Stimulus with controller autoloading"
unless File.exist?("app/javascript/controllers/application.js")
  copy_file "#{__dir__}/stimulus/application.js", "app/javascript/controllers/application.js"
end
copy_file "#{__dir__}/stimulus/autoload.js", "app/javascript/controllers/autoload.js"

if Dir.glob("app/javascript/controllers/**/*_controller.js").empty?
  copy_file "#{__dir__}/stimulus/hello_controller.js", "app/javascript/controllers/hello_controller.js"
end

if !File.exist?(entry)
  create_file entry, %(import "./controllers/autoload"\n)
elsif File.read(entry).match?(%r{^import ["']\./controllers(/index(\.js)?)?["'];?$})
  say "Replacing the controllers/index.js import with controllers/autoload"
  gsub_file entry, %r{^import ["']\./controllers(/index(\.js)?)?["'];?$}, %(import "./controllers/autoload")
elsif !File.read(entry).include?("./controllers/autoload")
  append_to_file entry, %(import "./controllers/autoload"\n)
end

if File.exist?("app/javascript/controllers/index.js")
  say "app/javascript/controllers/index.js is no longer imported; controllers/autoload.js replaces it.", :yellow
end

say "Installing @hotwired/stimulus"
run pm.add_command("@hotwired/stimulus")

say "Stimulus installed. Controllers in app/javascript/controllers are registered automatically.", :green
