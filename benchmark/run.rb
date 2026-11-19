# frozen_string_literal: true

# Times the same app with rspack, esbuild and webpack: production and
# development builds (median of 5), and the watch-mode rebuild after editing
# one leaf component (median of 10, until the bundle on disk has the edit).
#
#   npm install
#   ruby run.rb 1000

require "fileutils"

COUNT = Integer(ARGV.fetch(0, 1000))
LEAF = "src/components/group#{(COUNT - 1) / 100}/C#{COUNT - 1}.tsx".freeze
LABEL = %(label = "c#{COUNT - 1}").freeze

# The flags jsbundling-rails uses, plus the JSX runtime, the target and the
# NODE_ENV that React needs.
ESBUILD = "npx esbuild src/application.tsx --bundle --sourcemap --format=esm --outdir=out/esbuild " \
          "--jsx=automatic --target=es2022 --log-level=warning"
PRODUCTION = %(--define:process.env.NODE_ENV='"production"')
DEVELOPMENT = %(--define:process.env.NODE_ENV='"development"')

TOOLS = {
  "rspack" => { build: "npx rspack build --config rspack.config.mjs",
                watch: "npx rspack build --watch --config rspack.config.mjs" },
  "esbuild" => { prod: "#{ESBUILD} --minify #{PRODUCTION}", dev: "#{ESBUILD} #{DEVELOPMENT}",
                 watch: "#{ESBUILD} #{DEVELOPMENT} --watch=forever" },
  "webpack" => { build: "npx webpack build --config webpack.config.mjs",
                 watch: "npx webpack build --watch --config webpack.config.mjs" }
}.freeze

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
def median(times) = times.sort[times.size / 2]
def pause(seconds) = IO.select(nil, nil, nil, seconds)

def timed(env, command)
  started = now
  system(env, command, out: File::NULL, err: File::NULL) || abort("failed: #{command}")
  now - started
end

def cold(name, mode, runs: 5)
  tool = TOOLS.fetch(name)
  command = tool[mode] || tool.fetch(:build)
  env = { "NODE_ENV" => mode == :prod ? "production" : "development" }
  timed(env, command) # warms the OS file cache
  median(Array.new(runs) { timed(env, command) })
end

def written?(bundle, marker)
  600.times do
    return true if File.exist?(bundle) && File.read(bundle).include?(marker)

    pause(0.005)
  end
  false
end

def rebuild(name, edits: 10)
  original = File.read(LEAF)
  bundle = "out/#{name}/application.js"
  pid = spawn({ "NODE_ENV" => "development" }, TOOLS.fetch(name).fetch(:watch),
              out: File::NULL, err: File::NULL, pgroup: true)
  written?(bundle, LABEL.split('"').last) || abort("#{name} --watch never wrote #{bundle}")
  pause(1)
  median(Array.new(edits) { |index| edit(name, original, bundle, index) })
ensure
  Process.kill("TERM", -pid) if pid
  File.write(LEAF, original) if original
end

def edit(name, original, bundle, index)
  marker = "edit-#{name}-#{index}-#{rand(1_000_000)}"
  started = now
  File.write(LEAF, original.sub(LABEL, %(label = "#{marker}")))
  written?(bundle, marker) || abort("#{name} did not rebuild after an edit")
  elapsed = now - started
  pause(0.3)
  elapsed
end

system("ruby", "generate.rb", COUNT.to_s, exception: true)
puts "| #{COUNT} components | production build | development build | rebuild after editing one component |"
puts "|---|---|---|---|"
TOOLS.each_key do |name|
  prod = cold(name, :prod)
  dev = cold(name, :dev)
  puts format("| %<name>s | %<prod>.2f s | %<dev>.2f s | %<rebuild>.0f ms |",
              name: name, prod: prod, dev: dev, rebuild: rebuild(name) * 1000)
end
