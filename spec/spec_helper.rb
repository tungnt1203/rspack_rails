# frozen_string_literal: true

require "rspack_rails"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

# A managed file as another version of the gem wrote it: stamped with that
# version and a valid checksum of its own, so it counts as outdated, not edited.
def older_managed(file = RspackRails::ManagedFile::BASE)
  text = file.content.sub("rspack_rails #{RspackRails::VERSION}", "rspack_rails 0.18.0")
  text.sub(RspackRails::ManagedFile::CHECKSUM_LINE, "// Checksum: #{RspackRails::ManagedFile.checksum(text)}")
end
