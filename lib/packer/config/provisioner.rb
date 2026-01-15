require "securerandom"

class Provisioner
  def initialize(os, iaas, enable_ephemeral_disk, version, http_proxy = nil, https_proxy = nil, bypass_list = nil, build_context = nil)
    @iaas = iaas
    @ephemeral_disk_flag = enable_ephemeral_disk ? " -EnableEphemeralDiskMounting" : ""
    @version = version
    @proxy_settings = (http_proxy || https_proxy) ? "\\\"#{http_proxy}\\\" \\\"#{https_proxy}\\\" \\\"#{bypass_list}\\\"" : ""
    @install_windows_updates = (build_context != :patchfile)

    filename = File.expand_path("../templates/provision_#{os}.json.erb", __FILE__)
    @erb = ERB.new(File.read(filename))
  end

  def dump
    result = @erb.result_with_hash({
      iaas: @iaas,
      password: SecureRandom.hex(10) + "!",
      ephemeral_disk_flag: @ephemeral_disk_flag,
      proxy_settings: @proxy_settings,
      install_windows_updates: @install_windows_updates,
      stemcell_version: @version
    })
    JSON.parse(result)
  end
end
