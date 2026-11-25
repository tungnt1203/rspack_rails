# frozen_string_literal: true

# Rails application template: a new app bundled with rspack_rails.
#
#   rails new myapp -m https://raw.githubusercontent.com/tungnt1203/rspack_rails/main/template.rb
#
# Works with the default `rails new` (importmap, migrated to rspack) and with
# --skip-javascript or -j esbuild. It writes rspack.config.mjs and the entry
# point; Sass, Tailwind CSS, React and the like are yours to add (docs/guide.md).

# RSPACK_RAILS_PATH points at a local checkout (used by this gem's own CI).
if ENV["RSPACK_RAILS_PATH"]
  gem "rspack_rails", path: ENV["RSPACK_RAILS_PATH"]
else
  gem "rspack_rails"
end

after_bundle do
  if File.exist?("config/importmap.rb") || File.read("Gemfile").include?("jsbundling-rails")
    # rspack:migrate refuses to run on a dirty git tree; a new app is all uncommitted.
    run "RSPACK_TEMPLATE=1 RSPACK_FORCE=1 bin/rails rspack:migrate", abort_on_failure: true
  else
    # RSPACK_TEMPLATE: the installer's "Run bin/dev" waits for the closing message below.
    run "RSPACK_TEMPLATE=1 bin/rails rspack:install", abort_on_failure: true
  end

  rails_command "rspack:build", abort_on_failure: true
  say
  say "rspack_rails is set up. Run bin/dev to start.", :green
end
