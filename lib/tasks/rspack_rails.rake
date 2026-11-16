# frozen_string_literal: true

require "rspack_rails/installer"
require "rspack_rails/rspack_config"

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
    if dirty && RspackRails.env_var("RSPACK_FORCE", "FORCE").to_s.empty?
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
    command = RspackRails::PackageManager.detect(Rails.root).install_command
    system(command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
  end

  desc "Update config/rspack/rails.mjs (and the Stimulus and React loaders) to this version of rspack_rails " \
       "(rspack:build does it too)"
  task :sync do
    if RspackRails::RspackConfig.managed?(Rails.root)
      RspackRails::ManagedFile::ALL.each do |file|
        result = file.sync(Rails.root)
        puts "Updated #{result.path}" if result.written
        warn file.edits_message(result.backup) if result.backup
      end
    else
      warn "rspack.config.mjs does not build on #{RspackRails::RspackConfig::BASE}. Re-run " \
           "`bin/rails rspack:install` and accept the new rspack.config.mjs to have rspack_rails keep it up to date."
    end
  end

  desc "Build JavaScript bundles with rspack"
  task build: %i[sync dependencies] do
    command = RspackRails::PackageManager.detect(Rails.root).run_command("build")
    # `rspack build` defaults NODE_ENV to production. Development and test
    # builds keep source maps and skip minification; staging etc. stay production.
    node_env = Rails.env.development? || Rails.env.test? ? "development" : "production"
    env = { "NODE_ENV" => ENV.fetch("NODE_ENV", node_env) }
    system(env, command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
  end

  desc "Analyze the production bundle with Rsdoctor (report in tmp/rsdoctor)"
  task analyze: %i[sync dependencies] do
    app = RspackRails::App.new(Rails.root)
    pm = app.package_manager
    unless RspackRails::RspackConfig.managed?(Rails.root) ||
           app.read(RspackRails::RspackConfig::APP).to_s.include?("RsdoctorRspackPlugin")
      raise RspackRails::Error,
            "rspack.config.mjs predates rspack:analyze. Re-run `bin/rails rspack:install` and accept the new config."
    end

    unless app.dependency?("@rsdoctor/rspack-plugin")
      command = pm.add_dev_command("@rsdoctor/rspack-plugin")
      system(command, chdir: Rails.root) || raise(RspackRails::Error, "#{command} failed")
    end

    command = pm.run_command("build")
    system({ "RSDOCTOR" => "true", "NODE_ENV" => "production" }, command, chdir: Rails.root) ||
      raise(RspackRails::Error, "#{command} failed")
    puts "Rsdoctor report: #{Rails.root.join("tmp/rsdoctor/rsdoctor-report.html")}"
  end

  desc "Remove rspack build output from app/assets/builds"
  task :clobber do
    RspackRails::Entrypoints.outputs(Rails.root).each { |file| FileUtils.rm_f(file) }
  end
end

unless RspackRails.env_var("RSPACK_SKIP_BUILD", "SKIP_RSPACK_BUILD")
  %w[assets:precompile test:prepare spec:prepare db:test:prepare].each do |name|
    Rake::Task[name].enhance(["rspack:build"]) if Rake::Task.task_defined?(name)
  end
end

Rake::Task["assets:clobber"].enhance(["rspack:clobber"]) if Rake::Task.task_defined?("assets:clobber")
