# frozen_string_literal: true

RSpec.describe RspackRails do
  it "has a version number" do
    expect(RspackRails::VERSION).not_to be_nil
  end

  it "deprecates toward 3.0" do
    expect(described_class.deprecator.deprecation_horizon).to eq("3.0")
  end

  describe ".manifest" do
    let(:dev_server) { instance_double(RspackRails::DevServer, running?: false) }

    before { allow(described_class).to receive(:dev_server).and_return(dev_server) }
    after { described_class.instance_variable_set(:@manifests, nil) }

    it "keeps one manifest per app root" do
      first = described_class.manifest
      expect(described_class.manifest).to be(first)
      expect(first.root).to eq(Pathname(Dir.pwd))
    end

    it "reads another app's manifest when the root changes" do
      Dir.mktmpdir do |dir|
        described_class.manifest
        Dir.chdir(dir) { expect(described_class.manifest.root).to eq(Pathname(Dir.pwd)) }
      end
    end

    context "with both manifests written" do
      around do |example|
        Dir.mktmpdir do |dir|
          root = Pathname(dir).realpath
          root.join("public/rspack").mkpath
          root.join(RspackRails::Manifest::PATH).write('{"entries":{"application":{"js":["application.js"]}}}')
          root.join(RspackRails::Manifest::DEV_PATH)
              .write('{"entries":{"application":{"js":["runtime.js","application.js"]}}}')
          Dir.chdir(root) { example.run }
        end
      end

      it "reads the dev server's manifest while it runs, so a build alongside it does not drop runtime.js" do
        allow(dev_server).to receive(:running?).and_return(true)
        expect(described_class.manifest["application"].scripts).to eq(["runtime.js", "application.js"])
      end

      it "reads the build's manifest when the dev server is not running" do
        expect(described_class.manifest["application"].scripts).to eq(["application.js"])
      end

      it "reads the build's manifest under a dev server whose rails.mjs predates the dev manifest" do
        allow(dev_server).to receive(:running?).and_return(true)
        File.delete(RspackRails::Manifest::DEV_PATH)
        expect(described_class.manifest["application"].scripts).to eq(["application.js"])
      end
    end
  end
end
