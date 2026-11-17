# frozen_string_literal: true

RSpec.describe RspackRails do
  it "has a version number" do
    expect(RspackRails::VERSION).not_to be_nil
  end

  describe ".env_var" do
    it "reads the variable" do
      expect(described_class.env_var("RSPACK_FORCE", "FORCE", { "RSPACK_FORCE" => "1" })).to eq("1")
      expect(described_class.env_var("RSPACK_FORCE", "FORCE", {})).to be_nil
    end

    it "falls back to its name before 1.0, with a deprecation warning" do
      expect { expect(described_class.env_var("RSPACK_FORCE", "FORCE", { "FORCE" => "1" })).to eq("1") }
        .to output(/FORCE is deprecated.*Set RSPACK_FORCE instead/).to_stderr
    end

    it "prefers the new name without a warning when both are set" do
      env = { "RSPACK_SKIP_BUILD" => "1", "SKIP_RSPACK_BUILD" => "1" }
      expect { described_class.env_var("RSPACK_SKIP_BUILD", "SKIP_RSPACK_BUILD", env) }.not_to output.to_stderr
    end
  end
end
