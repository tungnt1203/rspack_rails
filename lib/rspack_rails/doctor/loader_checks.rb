# frozen_string_literal: true

require_relative "checks"
require_relative "../managed_file"

module RspackRails
  class Doctor
    # Stimulus and the loaders the Stimulus and React installers copy in.
    class LoaderChecks < Checks
      # By ManagedFile#state.
      STATES = {
        edited: [:warn, "%s has hand edits, which the next rspack:build replaces",
                 "Copy it to a file of your own, import that instead and delete %s"],
        outdated: [:warn, "%s is not the one from rspack_rails #{VERSION}",
                   "Run `bin/rails rspack:sync` (rspack:build does it too)"],
        current: [:ok, "%s from rspack_rails #{VERSION}", nil]
      }.freeze

      def checks
        [stimulus_check, loader_check(ManagedFile::STIMULUS, "Stimulus loader"),
         loader_check(ManagedFile::REACT, "React loader")]
      end

      private

      def stimulus_check
        return unless exist?("app/javascript/controllers/autoload.js")

        if node_modules_package("@hotwired/stimulus")
          Check.new(:ok, "Stimulus", "autoload enabled")
        else
          Check.new(:error, "Stimulus", "@hotwired/stimulus is not installed",
                    "Run `#{package_manager.add_command("@hotwired/stimulus")}`")
        end
      end

      def loader_check(file, name)
        state = file.state(root)
        return if state == :missing

        status, detail, hint = STATES.fetch(state)
        Check.new(status, name, format(detail, file.path), hint&.gsub("%s", file.path))
      end
    end
  end
end
