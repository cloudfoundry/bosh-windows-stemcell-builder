require "spec_helper"

RSpec.describe Packer::Config::Gcp do
  let(:os) { "windows2019" }

  describe "builders" do
    before(:each) do
      Timecop.freeze
    end

    after(:each) do
      Timecop.return
    end

    let(:repo_root) { File.expand_path("../../..", __dir__) }
    let(:setup_winrm_ps1_path) { File.join(repo_root, "scripts", "gcp", "setup-winrm.ps1") }
    let(:expected_sysprep_script_ps1) { File.read(setup_winrm_ps1_path) }

    let(:builders) {
      Packer::Config::Gcp.new(
        account_json: "some-account-json",
        project_id: "some-project-id",
        source_image: "some-source-image",
        output_directory: "",
        image_family: "some-image-family",
        os: os,
        version: "",
        vm_prefix: "some-vm-prefix",
        vm_type: "some-vm-type"
      ).builders
    }

    let(:baseline_builders) do
      {
        "type" => "googlecompute",
        "credentials_json" => "some-account-json",
        "project_id" => "some-project-id",
        "tags" => ["winrm"],
        "source_image" => "some-source-image",
        "image_family" => "some-image-family",
        "zone" => "us-west1-c",
        "disk_size" => 32,
        "image_name" => "packer-#{Time.now.to_i}",
        "machine_type" => "some-vm-type",
        "network" => nil,
        "network_project_id" => nil,
        "subnetwork" => nil,
        "omit_external_ip" => false,
        "use_internal_ip" => false,
        "communicator" => "winrm",
        "winrm_username" => "winrmuser",
        "winrm_use_ssl" => false,
        "winrm_timeout" => "1h",
        "state_timeout" => "10m",
        "metadata" => {
          "sysprep-specialize-script-ps1" => expected_sysprep_script_ps1,
          "name" => "some-vm-prefix-#{Time.now.to_i}"
        }
      }
    end

    it "returns the expected googlecompute builder" do
      expect(builders[0]).to eq(baseline_builders)
    end

    it "embeds sysprep-specialize-script-ps1 from the repo checkout (not a mutable URL)" do
      expect(builders[0]["metadata"]["sysprep-specialize-script-ps1"]).to eq(expected_sysprep_script_ps1)
      expect(builders[0]["metadata"]).not_to have_key("sysprep-specialize-script-url")
    end

    it "embeds sysprep script content within GCE metadata inline size limit" do
      script = builders[0]["metadata"]["sysprep-specialize-script-ps1"]
      expect(script.bytesize).to be <= Packer::Config::Gcp::SYSPREP_SPECIALIZE_SCRIPT_METADATA_MAX_BYTES
    end

    it "raises ArgumentError when setup-winrm.ps1 content exceeds GCE metadata size limit" do
      limit = Packer::Config::Gcp::SYSPREP_SPECIALIZE_SCRIPT_METADATA_MAX_BYTES
      oversize_bytes = limit + 1
      huge_script = "x" * oversize_bytes

      allow(File).to receive(:read).and_wrap_original do |method, *args, **kwargs, &block|
        path = args.first.to_s
        if path.end_with?("scripts/gcp/setup-winrm.ps1")
          huge_script
        else
          method.call(*args, **kwargs, &block)
        end
      end

      expect {
        Packer::Config::Gcp.new(
          account_json: "some-account-json",
          project_id: "some-project-id",
          source_image: "some-source-image",
          output_directory: "",
          image_family: "some-image-family",
          os: os,
          version: "",
          vm_prefix: "some-vm-prefix",
          vm_type: "some-vm-type"
        ).builders
      }.to raise_error(
        ArgumentError,
        /sysprep-specialize-script-ps1 content from .*setup-winrm\.ps1 is #{oversize_bytes} bytes, .*#{limit} bytes/
      )
    end

    context "when vm_prefix is empty" do
      it "defaults to packer" do
        builders = Packer::Config::Gcp.new(
          account_json: "",
          project_id: "",
          source_image: "",
          output_directory: "",
          image_family: "",
          os: "",
          version: "",
          vm_prefix: "",
          vm_type: ""
        ).builders
        expect(builders[0]["metadata"]).to include(
          "name" => "packer-#{Time.now.to_i}"
        )
      end
    end
  end

  describe "provisioners" do
    before(:each) do
      @stemcell_deps_dir = Dir.mktmpdir("gcp")
      ENV["STEMCELL_DEPS_DIR"] = @stemcell_deps_dir
    end

    after(:each) do
      FileUtils.rm_rf(@stemcell_deps_dir)
      ENV.delete("STEMCELL_DEPS_DIR")
    end

    let(:build_version) { "2019.43.17-build.1" }

    let(:provisioners) do
      Packer::Config::Gcp.new(
        account_json: "{}",
        project_id: "",
        source_image: "{}",
        output_directory: "some-output-directory",
        image_family: "",
        os: os,
        version: build_version,
        vm_prefix: "",
        vm_type: ""
      ).provisioners
    end

    let(:iaas_name) { "gcp" }
    it_behaves_like "standard provisioners"

    it "returns the expected provisioners" do
      allow(SecureRandom).to receive(:hex).and_return("some-password")

      expected_provisioners_base = [
        {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip", "pause_before" => "60s"},
        {"type" => "file", "source" => "scripts/install-bosh-psmodules.ps1", "destination" => "C:\\provision\\install-bosh-psmodules.ps1", "pause_before" => "60s"},
        {"type" => "powershell", "inline" => ['$ErrorActionPreference = "Stop";', 'C:\\provision\\install-bosh-psmodules.ps1'], "pause_before" => "60s"},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-DockerPackage"]},
        {"type" => "windows-restart", "restart_timeout" => "1h", "check_registry" => true},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures -IaaS gcp"]},
        {"type" => "windows-restart", "restart_timeout" => "1h", "check_registry" => true},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Wait-WindowsUpdates -Password some-password! -User Provisioner"]},
        {"type" => "windows-restart", "restart_timeout" => "12h", "check_registry" => true},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-HotFix | Out-File -FilePath hotfixes.log -Encoding utf8"]},
        {"type" => "file", "source" => "hotfixes.log", "destination" => "hotfixes.log", "direction" => "download"},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
        {"type" => "file", "source" => "../sshd/OpenSSH-Win64.zip", "destination" => "C:\\provision\\OpenSSH-Win64.zip"},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-SSHD"]},
        {"type" => "file", "source" => "build/agent.zip", "destination" => "C:\\provision\\agent.zip"},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS gcp -agentZipPath 'C:\\provision\\agent.zip'"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-RC4"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS1"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS11"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-TLS12"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-3DES"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-WUCerts"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-SSHKeys"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Set-InternetExplorerRegistries"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell -IaaS gcp; Invoke-Sysprep -IaaS gcp"]}
      ].flatten
      expect(provisioners.detect { |x| x["destination"] == "C:\\windows\\LGPO.exe" }).not_to be_nil

      expect(
        provisioners.detect { |p| p.has_key?("inline") && p["inline"].include?("New-VersionFile -Version '#{build_version}'") }
      ).not_to(be_nil, "Expect provisioners to include New-VersionFile")

      line_by_line_provisioners = provisioners.delete_if { |x| x["destination"] == "C:\\windows\\LGPO.exe" }
      line_by_line_provisioners =
        line_by_line_provisioners.delete_if { |p| p.has_key?("inline") && p["inline"].include?("New-VersionFile -Version '#{build_version}'") }

      expect(line_by_line_provisioners).to eq(expected_provisioners_base)
    end
  end
end
