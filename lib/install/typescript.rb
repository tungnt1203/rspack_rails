# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:typescript`.
require "json"

pm = RspackRails::PackageManager.detect(Rails.root)

say "Adding tsconfig.json"
copy_file "#{__dir__}/typescript/tsconfig.json", "tsconfig.json"

say "Adding typecheck script"
package = JSON.parse(File.read("package.json"))
(package["scripts"] ||= {})["typecheck"] = "tsc --noEmit"
File.write("package.json", "#{JSON.pretty_generate(package)}\n")

say "Installing typescript and ts-checker-rspack-plugin"
run pm.add_dev_command("typescript", "ts-checker-rspack-plugin"), abort_on_failure: true

say "TypeScript ready. Rspack compiles .ts files, type errors show in the dev server overlay, and " \
    "`#{pm.run_command("typecheck")}` type-checks the whole app.", :green
