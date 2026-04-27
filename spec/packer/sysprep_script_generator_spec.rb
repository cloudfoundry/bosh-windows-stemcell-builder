# frozen_string_literal: true

require "spec_helper"

RSpec.describe Packer::SysprepScriptGenerator do
  let(:repo_root) { File.expand_path("../..", __dir__) }

  subject(:generator) { described_class.new(stemcell_builder_dir: repo_root) }

  describe "#content" do
    it "rejects unknown platforms" do
      expect { generator.content(iaas: :azure) }.to raise_error(
        ArgumentError,
        /unsupported iaas: :azure/
      )
    end

    it "rejects nil with ArgumentError instead of NoMethodError" do
      expect { generator.content(iaas: nil) }.to raise_error(
        ArgumentError,
        "unsupported iaas: nil (expected :gcp or :aws)"
      )
    end

    it "rejects values without #to_sym with ArgumentError" do
      expect { generator.content(iaas: 123) }.to raise_error(
        ArgumentError,
        "unsupported iaas: 123 (expected :gcp or :aws)"
      )
    end

    context "for :gcp" do
      let(:script) { generator.content(iaas: :gcp) }

      it "accepts string 'gcp'" do
        expect(generator.content(iaas: "gcp")).to eq(script)
      end

      it "does not fetch WinRM module from the network" do
        expect(script).not_to include("Invoke-WebRequest")
        expect(script).not_to include("raw.githubusercontent.com")
      end

      it "includes WinRM module content from the repo (inlined source + invoked at end)" do
        expect(script).to include("function Enable-WinRM")
        expect(script).to include("function runCmd")
        expect(script).to match(/Write-Log "Invoking WinRM"\s*\nEnable-WinRM\z/m)
      end

      it "inlines module source without base64 decode or Import-Module" do
        expect(script).not_to include("$boshWinRMModuleB64")
        expect(script).not_to include("[IO.File]::WriteAllBytes")
        expect(script).not_to include("Import-Module -Name $modulePath")
      end

      it "stays within GCE metadata inline script size limit" do
        expect(script.bytesize).to be <= described_class::GCP_METADATA_MAX_BYTES
      end

      it "raises ArgumentError when generated script exceeds GCE metadata limit" do
        huge = "x" * (described_class::GCP_METADATA_MAX_BYTES + 1)
        gen = described_class.new(stemcell_builder_dir: repo_root)
        allow(gen).to receive(:build_core_powershell).and_return(huge)
        expect { gen.content(iaas: :gcp) }.to raise_error(
          ArgumentError,
          /GCE sysprep-specialize-script-ps1 metadata is .* \(limit .* bytes/
        )
      end
    end

    context "for :aws" do
      let(:user_data) { generator.content(iaas: :aws) }

      it "accepts string 'aws'" do
        expect(generator.content(iaas: "aws")).to eq(user_data)
      end

      it "wraps PowerShell in powershell tags and sets execution policy" do
        expect(user_data).to start_with("<powershell>")
        expect(user_data).to end_with("</powershell>")
        expect(user_data).to include("Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine")
      end

      it "does not fetch WinRM module from the network" do
        expect(user_data).not_to include("Invoke-WebRequest")
        expect(user_data).not_to include("raw.githubusercontent.com")
      end

      it "stays within EC2 user data size limit" do
        expect(user_data.bytesize).to be <= described_class::EC2_USER_DATA_MAX_BYTES
      end

      it "raises ArgumentError when user_data exceeds EC2 limit" do
        gen = described_class.new(stemcell_builder_dir: repo_root)
        inner = "y" * 20_000
        allow(gen).to receive(:build_core_powershell).and_return(inner)
        expect { gen.content(iaas: :aws) }.to raise_error(ArgumentError, /EC2 user_data/)
      end
    end
  end
end
