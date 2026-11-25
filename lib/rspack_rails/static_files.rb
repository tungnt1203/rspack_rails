# frozen_string_literal: true

require "action_dispatch"
require "action_dispatch/middleware/static"

module RspackRails
  # Serves public/rspack under /rspack/ the way Rails serves any file in
  # public/ (ETag, Range, pre-compressed .br and .gz files), but with a
  # far-future Cache-Control: rspack puts a fingerprint in the name of every
  # file it writes there, so a name never changes what it holds. Rails
  # applies its own cache header to public/ only through
  # config.public_file_server.headers, for everything alike.
  #
  # Only installed when config.public_file_server.enabled is on; with a web
  # server in front that serves public/ itself, give /rspack/ the same header there.
  class StaticFiles
    PREFIX = "/rspack/"
    CACHE_CONTROL = "public, max-age=31536000, immutable"

    def initialize(app, root:)
      @app = app
      @files = ActionDispatch::FileHandler.new(root.to_s, headers: { "cache-control" => CACHE_CONTROL })
    end

    def call(env)
      path = env["PATH_INFO"].to_s
      return @app.call(env) unless serves?(path)

      @files.attempt(env.merge("PATH_INFO" => path.delete_prefix(PREFIX.chomp("/")))) || @app.call(env)
    end

    private

    # Not the manifests (dotfiles): they change with every build.
    def serves?(path)
      path.start_with?(PREFIX) && !File.basename(path).start_with?(".")
    end
  end
end
