# frozen_string_literal: true

require_relative "rspack_config"

module RspackRails
  # Installer steps for the two rspack config files (see RspackConfig). Part of
  # RspackRails::Installer, so they run inside a Rails generator with Thor actions.
  module ConfigInstaller
    # Writes config/rspack/rails.mjs and, unless the app already has one built
    # on it, rspack.config.mjs. A standalone rspack.config.mjs from before
    # 0.13.0 is replaced after asking (Thor shows a diff on "d").
    def install_rspack_config
      sync_rspack_config
      return if RspackConfig.managed?(destination_root)

      if rspack_app.file?(RspackConfig::APP)
        say "rspack.config.mjs now builds on #{RspackConfig::BASE}, which rspack_rails updates on its own. " \
            "Accept the new file, then move your changes into its railsConfig callback.", :yellow
      end
      create_file RspackConfig::APP, File.read(File.expand_path("../install/rspack.config.mjs", __dir__))
    end

    # Exits unless the app's rspack config supports the feature being
    # installed. A config built on config/rspack/rails.mjs always does once
    # that file is current; an older standalone one must mention `marker`.
    def require_config!(marker, feature)
      return sync_rspack_config if RspackConfig.managed?(destination_root)
      return if rspack_app.read(RspackConfig::APP).to_s.include?(marker)

      say "rspack.config.mjs predates #{feature} support. Re-run `bin/rails rspack:install` and accept the new " \
          "rspack.config.mjs, then run this task again.", :red
      exit 1
    end

    def sync_rspack_config
      result = RspackConfig.sync(destination_root)
      say "Writing #{RspackConfig::BASE} for rspack_rails #{VERSION}" if result.written
      say RspackConfig.edits_message(result.backup), :yellow if result.backup
    end
  end
end
