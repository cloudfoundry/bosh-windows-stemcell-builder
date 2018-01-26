require 'securerandom'

module Packer
  module Config
    class Base
      def self.pre_provisioners(os, skip_windows_update: false, reduce_mtu: false, iaas: '', http_proxy: '', https_proxy: '', bypass_list: '')
        pre = []
        if os == 'windows2012R2'
          pre = [
            Provisioners::BOSH_PSMODULES,
            Provisioners.setup_proxy_settings(http_proxy, https_proxy, bypass_list),
            Provisioners::NEW_PROVISIONER,
            Provisioners::INSTALL_CF_FEATURES_2012
          ]
        elsif os == 'windows2016'
          pre = [
            Provisioners::BOSH_PSMODULES,
            Provisioners.setup_proxy_settings(http_proxy, https_proxy, bypass_list),
            Provisioners::NEW_PROVISIONER,
            Provisioners::INSTALL_CF_FEATURES_2016,
          ]
          if iaas == 'aws'
            pre.insert(1, Provisioners::ADD_TEMP_PATCH, Provisioners::INSTALL_TEMP_PATCH)
          end
        end
        install_windows_updates = if skip_windows_update then [] else [Provisioners.install_windows_updates] end
        #temporarily disable 'test-installed-updates'
        if os == 'windows2016' && !skip_windows_update
          install_windows_updates.first.pop
        end
        pre + install_windows_updates + [Provisioners::PROTECT_CF_CELL, Provisioners::INSTALL_SSHD]
      end

      def self.post_provisioners(iaas, os='windows2012R2')
        provisioners = [
          Provisioners::CLEAR_PROXY_SETTINGS,
          Provisioners::CLEAR_PROVISIONER
        ]

        if iaas.downcase != 'vsphere'
          provisioners += Provisioners.sysprep_shutdown(iaas, os)
        else
          provisioners = [
            Provisioners::OPTIMIZE_DISK,
            Provisioners::COMPRESS_DISK
          ] + provisioners
        end

        provisioners
      end

      def dump
        JSON.dump(
          'builders' => builders,
          'provisioners' => provisioners
        )
      end
    end
  end
end
