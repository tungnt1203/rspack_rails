# frozen_string_literal: true

require "rspack_rails/installer"
require "rspack_rails/rspack_config"
require "rspack_rails/rake_tasks"

namespace :rspack do
  desc "Set up rspack in this Rails app"
  task :install do
    RspackRails::Installer.run("install", task: "rspack:install")
  end

  namespace :install do
    {
      stimulus: "Set up Stimulus with automatic controller registration",
      typescript: "Set up TypeScript type checking (tsconfig.json, typescript, typecheck script)",
      react: "Set up React with Fast Refresh and the react_component helper",
      sass: "Set up Sass (migrates from dartsass-rails)",
      tailwind: "Set up Tailwind CSS v4 (migrates from tailwindcss-rails)"
    }.each do |name, description|
      desc description
      task(name) { RspackRails::Installer.run(name.to_s) }
    end
  end

  desc "Migrate from importmap-rails or jsbundling-rails to rspack (RSPACK_FORCE=1 to skip the clean git check)"
  task :migrate do
    dirty = system("git", "rev-parse", "--is-inside-work-tree", out: File::NULL, err: File::NULL) &&
            !`git status --porcelain`.strip.empty?
    if dirty && ENV["RSPACK_FORCE"].to_s.empty?
      raise RspackRails::Error,
            "rspack:migrate removes and rewrites files. Commit or stash your changes first, or run with RSPACK_FORCE=1."
    end

    RspackRails::Installer.run("migrate", task: "rspack:migrate")
  end

  desc "Check the rspack setup of this app"
  task doctor: :environment do
    require "rspack_rails/doctor"
    doctor = RspackRails::Doctor.new(Rails.root)
    doctor.report
    exit 1 unless doctor.ok?
  end

  desc "Install JavaScript dependencies"
  task :dependencies do
    RspackRails::RakeTasks.run!(RspackRails::PackageManager.detect(Rails.root).install_command)
  end

  desc "Update config/rspack/rails.mjs (and the Stimulus and React loaders) to this version of rspack_rails " \
       "(rspack:build does it too)"
  task :sync do
    # The loaders do not depend on rspack.config.mjs: they are synced even when
    # it predates config/rspack/rails.mjs.
    config = RspackRails::RspackConfig
    base = config.managed?(Rails.root)
    warn "#{config::NOT_MANAGED}. #{config::REINSTALL} to have rspack_rails keep it up to date." unless base
    RspackRails::ManagedFile.sync_all(Rails.root, base: base).each do |result|
      puts "Updated #{result.path}"
      warn result.edits_message if result.backup
    end
  end

  desc "Build JavaScript bundles with rspack"
  task build: %i[sync dependencies] do
    command = RspackRails::PackageManager.detect(Rails.root).run_command("build")
    # `rspack build` defaults NODE_ENV to production. Development and test
    # builds keep source maps and skip minification; staging etc. stay production.
    node_env = Rails.env.development? || Rails.env.test? ? "development" : "production"
    RspackRails::RakeTasks.run!(command, env: { "NODE_ENV" => ENV.fetch("NODE_ENV", node_env) })
  end

  desc "Analyze the production bundle with Rsdoctor (report in tmp/rsdoctor)"
  task analyze: %i[sync dependencies] do
    app = RspackRails::App.new(Rails.root)
    pm = app.package_manager
    config = RspackRails::RspackConfig
    raise RspackRails::Error, "#{config::NOT_MANAGED}. #{config::REINSTALL}." unless config.managed?(Rails.root)

    RspackRails::RakeTasks.run!(pm.add_dev_command("@rsdoctor/rspack-plugin")) unless
      app.dependency?("@rsdoctor/rspack-plugin")
    RspackRails::RakeTasks.run!(pm.run_command("build"), env: { "RSDOCTOR" => "true", "NODE_ENV" => "production" })
    puts "Rsdoctor report: #{Rails.root.join("tmp/rsdoctor/rsdoctor-report.html")}"
  end

  desc "Remove the build output in public/rspack (and the output of rspack_rails 1.x in app/assets/builds)"
  task :clobber do
    FileUtils.rm_rf(Rails.root.join(RspackRails::Manifest::OUTPUT_DIR))
    RspackRails::Entrypoints.legacy_outputs(Rails.root).each { |file| FileUtils.rm_f(file) }
  end
end

# `assets:precompile` and `assets:clobber` exist without Propshaft or Sprockets
# too (a Dockerfile and Kamal run them); they do what rspack needs. With a
# pipeline, Rake adds these to the pipeline's own tasks, which run as before.
unless ENV.key?("RSPACK_SKIP_BUILD")
  %w[assets:precompile test:prepare spec:prepare db:test:prepare].each do |name|
    task name => "rspack:build"
  end
end

task "assets:clobber" => "rspack:clobber"
