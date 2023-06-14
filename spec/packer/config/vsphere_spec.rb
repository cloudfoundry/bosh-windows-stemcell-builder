require 'packer/config'
require 'timecop'

describe Packer::Config do
  before(:each) do
    Timecop.freeze(Time.now.getutc)
  end

  after(:each) do
    Timecop.return
  end

  describe 'VSphere' do
    describe 'builders' do
      it 'returns the expected builders' do
        builders = Packer::Config::VSphere.new(
            output_directory: 'output_directory',
            num_vcpus: 1,
            mem_size: 1000,
            product_key: 'key',
            organization: 'me',
            owner: 'me',
            administrator_password: 'password',
            source_path: 'source_path',
            os: 'windows2019',
            version: '',
            enable_rdp: false,
            new_password: 'new-password',
            http_proxy: '',
            https_proxy: '',
            bypass_list: ''
        ).builders
        expect(builders[0]).to eq(
                                   'type' => 'vmware-vmx',
                                   'source_path' => 'source_path',
                                   'headless' => false,
                                   'boot_wait' => '2m',
                                   'shutdown_command' => 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword new-password -ProductKey key -Owner me -Organization me',
                                   'shutdown_timeout' => '1h',
                                   'communicator' => 'winrm',
                                   'ssh_username' => 'Administrator',
                                   'winrm_username' => 'Administrator',
                                   'winrm_password' => 'password',
                                   'winrm_timeout' => '1h',
                                   'winrm_insecure' => true,
                                   'vm_name' => 'packer-vmx',
                                   'vmx_data' => {
                                       'memsize' => '1000',
                                       'numvcpus' => '1',
                                       'displayname' => "packer-vmx-#{Time.now.getutc.to_i}"
                                   },
                                   'output_directory' => 'output_directory'
                               )
      end

      it 'adds the EnableRdp flag to shutdown command' do
        builders = Packer::Config::VSphere.new(
            output_directory: 'output_directory',
            num_vcpus: 1,
            mem_size: 1000,
            product_key: 'key',
            organization: 'me',
            owner: 'me',
            administrator_password: 'password',
            source_path: 'source_path',
            os: 'windows2019',
            version: '',
            enable_rdp: true,
            new_password: 'new-password',
            http_proxy: '',
            https_proxy: '',
            bypass_list: ''
        ).builders
        expect(builders[0]['shutdown_command']).to eq 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword new-password -ProductKey key -Owner me -Organization me -EnableRdp'
      end

      it 'does not include -ProductKey if product key is empty string' do
        builders = Packer::Config::VSphere.new(
            output_directory: 'output_directory',
            num_vcpus: 1,
            mem_size: 1000,
            product_key: '',
            organization: 'me',
            owner: 'me',
            administrator_password: 'password',
            source_path: 'source_path',
            os: 'windows2019',
            version: '',
            enable_rdp: true,
            new_password: 'new-password',
            http_proxy: '',
            https_proxy: '',
            bypass_list: ''
        ).builders
        expect(builders[0]['shutdown_command']).to eq 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -Command Invoke-Sysprep -IaaS vsphere -NewPassword new-password -Owner me -Organization me -EnableRdp'
      end
    end

    describe 'provisioners' do
      before(:each) do
        @stemcell_deps_dir = Dir.mktmpdir('gcp')
        ENV['STEMCELL_DEPS_DIR'] = @stemcell_deps_dir
      end

      after(:each) do
        FileUtils.rm_rf(@stemcell_deps_dir)
        ENV.delete('STEMCELL_DEPS_DIR')
      end

      shared_examples 'proxy configurable' do
        let(:dummy_parameters) do
          {
            output_directory: 'output_directory',
            num_vcpus: 1,
            mem_size: 1000,
            product_key: 'key',
            organization: 'me',
            owner: 'me',
            administrator_password: 'password',
            source_path: 'source_path',
            os: os_version,
            version: '',
            enable_rdp: false,
            new_password: 'new-password',
            http_proxy: nil,
            https_proxy: nil,
            bypass_list: nil
          }
        end

        it "doesn't call Set-ProxySettings when no proxy settings are provided" do
          provisioners = Packer::Config::VSphere.new(**dummy_parameters).provisioners

          proxy_setting_entries = provisioners.select do |p|
            p.has_key?('inline') && p['inline'].any? { |l| l =~ /Set-ProxySettings/ }
          end
          expect(proxy_setting_entries.length).to eq(0)
        end

        it 'calls Set-ProxySettings with both proxies when http and https proxies are set' do
          provisioners = Packer::Config::VSphere.new(
            **dummy_parameters.merge(
                  http_proxy: 'foo',
                  https_proxy: 'bar',
                  bypass_list: 'bee'
              )
          ).provisioners

          proxy_setting_entries = provisioners.select do |p|
            p.has_key?('inline') && p['inline'].any? { |l| l =~ /Set-ProxySettings/ }
          end
          expect(proxy_setting_entries.length).to eq(1)

          proxy_setting_command = proxy_setting_entries[0]['inline'].detect{ |l| l =~ /Set-ProxySettings/}
          expect(proxy_setting_command).to eq 'Set-ProxySettings "foo" "bar" "bee"'
        end

        it 'Set-ProxySettings called with empty https proxy when only http proxy is set' do
          provisioners = Packer::Config::VSphere.new(
            **dummy_parameters.merge(
                  http_proxy: 'foo',
                  bypass_list: 'bee'
              )
          ).provisioners

          proxy_setting_entries = provisioners.select do |p|
            p.has_key?('inline') && p['inline'].any? { |l| l =~ /Set-ProxySettings/ }
          end
          expect(proxy_setting_entries.length).to eq(1)

          proxy_setting_command = proxy_setting_entries[0]['inline'].detect{ |l| l =~ /Set-ProxySettings/}
          expect(proxy_setting_command).to eq 'Set-ProxySettings "foo" "" "bee"'
        end


        it 'Set-ProxySettings called with empty http proxy when only https proxy is set' do
          provisioners = Packer::Config::VSphere.new(
            **dummy_parameters.merge(
                  https_proxy: 'bar',
                  bypass_list: 'bee'
              )
          ).provisioners

          proxy_setting_entries = provisioners.select do |p|
            p.has_key?('inline') && p['inline'].any? { |l| l =~ /Set-ProxySettings/ }
          end
          expect(proxy_setting_entries.length).to eq(1)

          proxy_setting_command = proxy_setting_entries[0]['inline'].detect{ |l| l =~ /Set-ProxySettings/}
          expect(proxy_setting_command).to eq 'Set-ProxySettings "" "bar" "bee"'
        end

      end

      context 'windows 2019' do
        it_behaves_like "proxy configurable" do
          let(:os_version) { 'windows2019' }
        end

        it 'returns the expected provisioners for the vmx build' do
          allow(SecureRandom).to receive(:hex).and_return('some-password')
          version = '2019.43.17-build.1'
          provisioners = Packer::Config::VSphere.new(
            output_directory: 'output_directory',
            num_vcpus: 1,
            mem_size: 1000,
            product_key: 'key',
            organization: 'me',
            owner: 'me',
            administrator_password: 'password',
            source_path: 'source_path',
            os: 'windows2019',
            version: version,
            enable_rdp: false,
            new_password: 'new-password',
            http_proxy: 'foo',
            https_proxy: 'bar',
            bypass_list: 'bee'
          ).provisioners
          expected_provisioners_base =
            [
              {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip", "pause_before"=>"60s"},
              {"type"=>"file", "source"=>"scripts/install-bosh-psmodules.ps1", "destination"=>"C:\\provision\\install-bosh-psmodules.ps1", "pause_before"=>"60s"},
              {"type"=>"powershell", "inline"=>['$ErrorActionPreference = "Stop";', 'C:\\provision\\install-bosh-psmodules.ps1'], "pause_before"=>"60s"},
              {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
                                                    'trap { $host.SetShouldExit(1) }',
                                                    'Set-ProxySettings "foo" "bar" "bee"']},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-DockerPackage"]},
              {"type" => "windows-restart", "restart_timeout"=>"1h", "check_registry" => true},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures2016"]},
              {"type" => "windows-restart", "restart_timeout"=>"1h", "check_registry" => true},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Add-Account -User Provisioner -Password some-password!"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Register-WindowsUpdatesTask"]},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Wait-WindowsUpdates -Password some-password! -User Provisioner"]},
              {"type" => "windows-restart", "restart_timeout" => "12h", "check_registry" => true},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Unregister-WindowsUpdatesTask"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-HotFix > hotfixes.log"]},
              {"type" => "file", "source" => "hotfixes.log", "destination" => "hotfixes.log", "direction" => "download"},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-Account -User Provisioner"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
              ## omitting LGPO provisioner because random string in it
              {"type" => "file", "source" => "../sshd/OpenSSH-Win64.zip", "destination" => "C:\\provision\\OpenSSH-Win64.zip"},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-SSHD"]},
              {"type" => "file", "source" => "build/agent.zip", "destination" => "C:\\provision\\agent.zip"},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS vsphere -agentZipPath 'C:\\provision\\agent.zip'"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-RC4"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS1"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS11"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-TLS12"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-3DES"]},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-WUCerts"]},
              {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
                                                    'trap { $host.SetShouldExit(1) }',
                                                    'Clear-ProxySettings']},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-SSHKeys"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Set-InternetExplorerRegistries"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Optimize-Disk"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Compress-Disk"]},
            ].flatten
          expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil

          expect(provisioners.detect do |p|
            p.has_key?('inline') && p['inline'].include?("New-VersionFile -Version '#{version}'")
          end).not_to be_nil, "Expect provisioners to include New-VersionFile"

          line_by_line_provisioners = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
          line_by_line_provisioners = line_by_line_provisioners.delete_if {|p| p.has_key?('inline') && p['inline'].include?("New-VersionFile -Version '#{version}'")}

          expect(line_by_line_provisioners).to eq (expected_provisioners_base)
        end

        it 'returns the expected provisioners for the patchfile build' do
          allow(SecureRandom).to receive(:hex).and_return('some-password')
          version = '2019.43.17-build.1'
          provisioners = Packer::Config::VSphere.new(
            output_directory: 'output_directory',
            num_vcpus: 1,
            mem_size: 1000,
            product_key: 'key',
            organization: 'me',
            owner: 'me',
            administrator_password: 'password',
            source_path: 'source_path',
            os: 'windows2019',
            version: version,
            enable_rdp: false,
            new_password: 'new-password',
            http_proxy: 'foo',
            https_proxy: 'bar',
            bypass_list: 'bee',
            build_context: :patchfile,
            ).provisioners
          expected_provisioners_base =
            [
              {"type" => "file", "source" => "build/bosh-psmodules.zip", "destination" => "C:\\provision\\bosh-psmodules.zip", "pause_before"=>"60s"},
              {"type"=>"file", "source"=>"scripts/install-bosh-psmodules.ps1", "destination"=>"C:\\provision\\install-bosh-psmodules.ps1", "pause_before"=>"60s"},
              {"type"=>"powershell", "inline"=>['$ErrorActionPreference = "Stop";', 'C:\\provision\\install-bosh-psmodules.ps1'], "pause_before"=>"60s"},
              {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
                                                    'trap { $host.SetShouldExit(1) }',
                                                    'Set-ProxySettings "foo" "bar" "bee"']},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "New-Provisioner"]},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-DockerPackage"]},
              {"type" => "windows-restart", "restart_timeout"=>"1h", "check_registry" => true},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-CFFeatures2016"]},
              {"type" => "windows-restart", "restart_timeout"=>"1h", "check_registry" => true},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Protect-CFCell"]},
              ## omitting LGPO provisioner because random string in it
              {"type" => "file", "source" => "../sshd/OpenSSH-Win64.zip", "destination" => "C:\\provision\\OpenSSH-Win64.zip"},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-SSHD -SSHZipFile 'C:\\provision\\OpenSSH-Win64.zip'"]},
              {"type"=>"powershell", "inline"=> ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-SSHD"]},
              {"type" => "file", "source" => "build/agent.zip", "destination" => "C:\\provision\\agent.zip"},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Install-Agent -IaaS vsphere -agentZipPath 'C:\\provision\\agent.zip'"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-RC4"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS1"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-TLS11"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Enable-TLS12"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Disable-3DES"]},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Get-WUCerts"]},
              {'type' => 'powershell', 'inline' => ['$ErrorActionPreference = "Stop";',
                                                    'trap { $host.SetShouldExit(1) }',
                                                    'Clear-ProxySettings']},
              {"type"=>"powershell", "inline"=>["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Remove-SSHKeys"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Clear-Provisioner"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Set-InternetExplorerRegistries"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Optimize-Disk"]},
              {"type" => "powershell", "inline" => ["$ErrorActionPreference = \"Stop\";", "trap { $host.SetShouldExit(1) }", "Compress-Disk"]},
            ].flatten
          expect(provisioners.detect {|x| x['destination'] == "C:\\windows\\LGPO.exe"}).not_to be_nil

          expect(provisioners.detect do |p|
            p.has_key?('inline') && p['inline'].include?("New-VersionFile -Version '#{version}'")
          end).not_to be_nil, "Expect provisioners to include New-VersionFile"

          line_by_line_provisioners = provisioners.delete_if {|x| x['destination'] == "C:\\windows\\LGPO.exe"}
          line_by_line_provisioners = line_by_line_provisioners.delete_if {|p| p.has_key?('inline') && p['inline'].include?("New-VersionFile -Version '#{version}'")}

          expect(line_by_line_provisioners).to eq (expected_provisioners_base)
        end

        context 'when provisioning with emphemeral disk mounting enabled' do
          it 'calls Install-Agent with -EnableEphemeralDiskMounting' do
            allow(SecureRandom).to receive(:hex).and_return("some-password")
            provisioners = Packer::Config::VSphere.new(
              output_directory: 'output_directory',
              num_vcpus: 1,
              mem_size: 1000,
              product_key: 'key',
              organization: 'me',
              owner: 'me',
              administrator_password: 'password',
              source_path: 'source_path',
              os: 'windows2019',
              version: '',
              enable_rdp: false,
              new_password: 'new-password',
              http_proxy: 'foo',
              https_proxy: 'bar',
              bypass_list: 'bee',
              mount_ephemeral_disk: true,
              ).provisioners

            expect(provisioners).to include(
                                      {
                                        "type" => "powershell",
                                        "inline" => [
                                          "$ErrorActionPreference = \"Stop\";",
                                          "trap { $host.SetShouldExit(1) }",
                                          "Install-Agent -IaaS vsphere -agentZipPath 'C:\\provision\\agent.zip' -EnableEphemeralDiskMounting"
                                        ]
                                      }
                                    )
          end
        end
      end

    end
  end
end
