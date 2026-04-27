require "spec_helper"

RSpec.describe Packer::Config::Aws do
  let(:os) { "windows2019" }

  describe "builders" do
    before(:each) do
      Timecop.freeze
    end

    after(:each) do
      Timecop.return
    end

    let(:region) do
      {
        name: "region1",
        base_ami: "baseami1",
        vpc_id: "vpc1",
        subnet_id: "subnet1",
        security_group: "sg1"
      }
    end

    let(:aws_role_arn) { "" }

    let(:repo_root) { File.expand_path("../../..", __dir__) }
    let(:expected_user_data) {
      Packer::SysprepScriptGenerator.new.content(iaas: :aws)
    }

    let(:builders) do
      Packer::Config::Aws.new(
        aws_access_key: "some-aws-access-key",
        aws_secret_key: "some-aws-secret-key",
        aws_role_arn: aws_role_arn,
        region: region,
        output_directory: "some-output-directory",
        os: os,
        version: "",
        vm_prefix: "some-vm-prefix"
      ).builders
    end

    let(:baseline_builders) do
      {
        name: "amazon-ebs-region1",
        type: "amazon-ebs",
        access_key: "some-aws-access-key",
        secret_key: "some-aws-secret-key",
        region: "region1",
        source_ami: "baseami1",
        instance_type: "m5.large",
        vpc_id: "vpc1",
        subnet_id: "subnet1",
        associate_public_ip_address: true,
        launch_block_device_mappings: [
          {
            device_name: "/dev/sda1",
            volume_size: 30,
            volume_type: "gp2",
            delete_on_termination: true
          }
        ],
        communicator: "winrm",
        winrm_username: "Administrator",
        winrm_timeout: "1h",
        security_group_id: "sg1",
        ami_groups: "all",
        user_data: expected_user_data,
        run_tags: {Name: "some-vm-prefix-#{Time.now.to_i}"}
      }
    end

    it "returns the baseline builders" do
      expect(builders[0]).to include(baseline_builders)
      expect(builders[0][:ami_name]).to match(/BOSH-.*-region1/)
      expect(builders[0][:user_data]).to eq(expected_user_data)
      expect(builders[0]).not_to have_key(:user_data_file)
      expect(builders[0][:assume_role]).to be_nil
    end

    context "when aws_role_arn is specified" do
      let(:aws_role_arn) { "role::arn" }
      it "configures packer for assume role" do
        expect(builders[0][:assume_role][:role_arn]).to equal(aws_role_arn)
      end
    end

    context "govcloud" do
      it "returns the baseline builders" do
        gov_region = {
          name: "region1-gov",
          base_ami: "baseami1",
          vpc_id: "vpc1",
          subnet_id: "subnet1",
          security_group: "sg1"
        }

        gov_builders = Packer::Config::Aws.new(
          aws_access_key: "some-aws-access-key",
          aws_secret_key: "some-aws-secret-key",
          region: gov_region,
          output_directory: "some-output-directory",
          os: os,
          version: "",
          vm_prefix: "some-vm-prefix"
        ).builders

        expect(gov_builders[0]).to include(baseline_builders.merge({
          region: "region1-gov",
          name: "amazon-ebs-region1-gov"
        }))
        expect(gov_builders[0][:ami_name]).to match(/BOSH-.*-region1/)
        expect(gov_builders[0][:user_data]).to eq(expected_user_data)
        expect(gov_builders[0]).not_to have_key(:user_data_file)
      end
    end

    context "when vm_prefix is empty" do
      it "defaults to packer" do
        builders = Packer::Config::Aws.new(
          aws_access_key: "",
          aws_secret_key: "",
          region: region,
          output_directory: "",
          os: "",
          version: "",
          vm_prefix: ""
        ).builders
        expect(builders[0]).to include(
          run_tags: {Name: "packer-#{Time.now.to_i}"}
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
      Packer::Config::Aws.new(
        aws_access_key: "",
        aws_secret_key: "",
        region: "",
        output_directory: "some-output-directory",
        os: os,
        version: build_version,
        vm_prefix: ""
      ).provisioners
    end

    let(:iaas_name) { "aws" }
    it_behaves_like "standard provisioners"

    it "returns the expected provisioners" do
      stemcell_deps_dir = Dir.mktmpdir("aws")
      ENV["STEMCELL_DEPS_DIR"] = stemcell_deps_dir

      allow(SecureRandom).to receive(:hex).and_return("some-password")

      expected_provisioners_base = [
        {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip", "pause_before" => "60s"},
        {"type" => "file", "source" => "scripts/install-bosh-psmodules.ps1", "destination" => "C:\\provision\\install-bosh-psmodules.ps1", "pause_before" => "60s"},
        {"type" => "powershell", "inline" => ['$ErrorActionPreference = "Stop";', 'C:\\provision\\install-bosh-psmodules.ps1'], "pause_before" => "60s"},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-DockerPackage"]},
        {"type" => "windows-restart", "restart_timeout" => "1h", "check_registry" => true},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures -IaaS aws"]},
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
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip'"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-RC4"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS1"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS11"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-TLS12"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-3DES"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-WUCerts"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-SSHKeys"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Set-InternetExplorerRegistries"]},
        {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell -IaaS aws; Invoke-Sysprep -IaaS aws"]}
      ].flatten
      expect(provisioners.detect { |x| x["destination"] == "C:\\windows\\LGPO.exe" }).not_to be_nil

      expect(
        provisioners.detect { |p| p.has_key?("inline") && p["inline"].include?("New-VersionFile -Version '#{build_version}'") }
      ).not_to(be_nil, "Expect provisioners to include New-VersionFile")

      line_by_line_provisioners = provisioners.delete_if { |x| x["destination"] == "C:\\windows\\LGPO.exe" }
      line_by_line_provisioners = line_by_line_provisioners.delete_if { |p| p.has_key?("inline") && p["inline"].include?("New-VersionFile -Version '#{build_version}'") }

      expect(line_by_line_provisioners).to eq(expected_provisioners_base)

      FileUtils.rm_rf(stemcell_deps_dir)
      ENV.delete("STEMCELL_DEPS_DIR")
    end

    context "when provisioning with ephemeral disk mounting enabled" do
      let(:provisioners) do
        Packer::Config::Aws.new(
          aws_access_key: "",
          aws_secret_key: "",
          region: "",
          output_directory: "some-output-directory",
          os: "windows2019",
          version: "",
          vm_prefix: "",
          mount_ephemeral_disk: true
        ).provisioners
      end

      it "calls Install-Agent with -EnableEphemeralDiskMounting" do
        allow(SecureRandom).to receive(:hex).and_return("some-password")

        expect(provisioners).to include(
          {
            "type" => "powershell",
            "inline" => [
              "$ErrorActionPreference = \"Stop\";",
              "trap { $host.SetShouldExit(1) }",
              "Install-Agent -IaaS aws -agentZipPath 'C:\\provision\\agent.zip' -EnableEphemeralDiskMounting"
            ]
          }
        )
      end
    end
  end
end
