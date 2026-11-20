# frozen_string_literal: true

module RspackRails
  # Helpers for the tasks in lib/tasks/rspack_rails.rake.
  module RakeTasks
    module_function

    # Runs a shell command in the app, or raises with the command that failed.
    def run!(command, env: {})
      system(env, command, chdir: Rails.root) || raise(Error, "#{command} failed")
    end
  end
end
