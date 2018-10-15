require 'securerandom'

class ProvisionerFactory
  def initialize(os, iaas, enable_ephemeral_disk, http_proxy = nil, https_proxy = nil, bypass_list = nil, build_context = nil)
    klass = "Provisioner::OS#{os}"
    @provisioner = Object.const_get(klass).new(os, iaas, enable_ephemeral_disk, http_proxy, https_proxy, bypass_list, build_context )
  end

  def dump
    @provisioner.dump
  end
end

class Provisioner
  def initialize(os, iaas, enable_ephemeral_disk, http_proxy = nil, https_proxy = nil, bypass_list = nil, build_context = nil)
    @iaas = iaas
    @ephemeral_disk_flag = enable_ephemeral_disk ? ' -EnableEphemeralDiskMounting' : ''
    @proxy_settings = http_proxy ? "#{http_proxy} #{https_proxy} #{bypass_list}" : ''
    @installWindowsUpdates = (build_context != :patchfile)

    filename = File.expand_path("../templates/provision_#{os}.json.erb", __FILE__)
    @erb = ERB.new(File.read(filename))
  end
end

class OSwindows2012R2 < Provisioner
  def dump
    result = @erb.result_with_hash({iaas: @iaas, password: SecureRandom.hex(10) + "!", proxy_settings: @proxy_settings})
    JSON.parse(result)
  end
end

class OSwindows2012R2_vsphere_updates < Provisioner
  def dump
    result = @erb.result_with_hash({iaas: @iaas, password: SecureRandom.hex(10) + "!", proxy_settings: @proxy_settings})
    JSON.parse(result)
  end
end

class OSwindows2016 < Provisioner
  def dump
    result = @erb.result_with_hash({iaas: @iaas, password: SecureRandom.hex(10) + "!", ephemeral_disk_flag: @ephemeral_disk_flag, proxy_settings: @proxy_settings, install_windows_updates: @installWindowsUpdates})
    JSON.parse(result)
  end
end

class OSwindows1803 < Provisioner
  def dump
    result = @erb.result_with_hash({iaas: @iaas, password: SecureRandom.hex(10) + "!", ephemeral_disk_flag: @ephemeral_disk_flag, proxy_settings: @proxy_settings, install_windows_updates: @installWindowsUpdates})
    JSON.parse(result)
  end
end
