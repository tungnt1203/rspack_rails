# frozen_string_literal: true

require "rspack_rails/installer"
require "rspack_rails/rake_tasks"

namespace :rspack do
  desc "Set up rspack in this Rails app"
  task :install do
    RspackRails::Installer.run("install", task: "rspack:install")
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

  desc "Build JavaScript bundles with rspack"
  task build: :dependencies do
    command = RspackRails::PackageManager.detect(Rails.root).run_command("build")
    # `rspack build` defaults NODE_ENV to production. Development and test
    # builds keep source maps and skip minification; staging etc. stay production.
    node_env = Rails.env.development? || Rails.env.test? ? "development" : "production"
    RspackRails::RakeTasks.run!(command, env: { "NODE_ENV" => ENV.fetch("NODE_ENV", node_env) })
  end

  desc "Remove the build output in public/rspack"
  task :clobber do
    FileUtils.rm_rf(Rails.root.join(RspackRails::Manifest::OUTPUT_DIR))
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
