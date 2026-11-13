# frozen_string_literal: true

# Rails application template run by `bin/rails rspack:install:typescript`.
require "rspack_rails/installer"
extend RspackRails::Installer

pm = RspackRails::PackageManager.detect(Rails.root)

say "Adding tsconfig.json"
copy_file "#{__dir__}/typescript/tsconfig.json", "tsconfig.json"
unless File.exist?("app/javascript/types/assets.d.ts")
  copy_file "#{__dir__}/typescript/assets.d.ts", "app/javascript/types/assets.d.ts"
end

say "Adding typecheck script"
update_package_json { |package| (package["scripts"] ||= {})["typecheck"] = "tsc --noEmit" }

say "Installing typescript and ts-checker-rspack-plugin"
run pm.add_dev_command("typescript", "ts-checker-rspack-plugin"), abort_on_failure: true

say "TypeScript ready. Rspack compiles .ts files, type errors show in the dev server overlay, and " \
    "`#{pm.run_command("typecheck")}` type-checks the whole app.", :green
