require 'securerandom'

module Packer
  module Config
    class Base
      def initialize(os:, output_directory:, vm_prefix: '', mount_ephemeral_disk: false)
        @os = os
        @output_directory = output_directory
        @vm_prefix = vm_prefix.empty? ? 'packer' : vm_prefix
        @mount_ephemeral_disk = mount_ephemeral_disk
      end

      def self.pre_provisioners(
          os,
          skip_windows_update: false,
          reduce_mtu: false,
          iaas: '',
          http_proxy: '',
          https_proxy: '',
          bypass_list: '',
          build_context: :stemcell
      )

        pre = []
        if os == 'windows2012R2'
          pre = [
            Provisioners::BOSH_PSMODULES,
            Provisioners.setup_proxy_settings(http_proxy, https_proxy, bypass_list),
            Provisioners::NEW_PROVISIONER,
            Provisioners::INSTALL_CF_FEATURES_2012
          ]
        elsif os == 'windows2016' || os == 'windows1803'
          pre = [
            Provisioners::BOSH_PSMODULES,
            Provisioners.setup_proxy_settings(http_proxy, https_proxy, bypass_list),
            Provisioners::NEW_PROVISIONER,
            ]

          azure1803 = iaas.downcase == 'azure' && os == 'windows1803'

          if azure1803 || (iaas.downcase == 'vsphere' && build_context == :patchfile)
            pre += [Provisioners::remove_docker()]
          end

          if azure1803
            pre += [Provisioners::INSTALL_CF_FEATURES_1803_AZURE]
          else
            pre += [Provisioners::INSTALL_CF_FEATURES_2016]
          end
        end
        install_windows_updates = if skip_windows_update then [] else [Provisioners.install_windows_updates] end

        #windows1709 and up fails 'test-installed-updates'
        if os == 'windows2016' || os == 'windows1803' && !skip_windows_update
          install_windows_updates.first.pop
        end
        pre + install_windows_updates + [Provisioners::PROTECT_CF_CELL, Provisioners::INSTALL_SSHD]
      end

      def self.post_provisioners(iaas)
        provisioners = [
          Provisioners::CLEAR_PROXY_SETTINGS,
          Provisioners::CLEAR_PROVISIONER
        ]

        if iaas.downcase != 'vsphere'
          provisioners += Provisioners.sysprep_shutdown(iaas)
        else
          provisioners = [
            Provisioners::OPTIMIZE_DISK,
            Provisioners::COMPRESS_DISK
          ] + provisioners
        end

        provisioners
      end

      def self.enable_security_patches(os)
        provisioners = []
        if os == 'windows2012R2'
          provisioners = [
              Provisioners::ENABLE_CVE_2015_6161,
              Provisioners::ENABLE_CVE_2017_8529,
              Provisioners::ENABLE_CREDSSP,
              Provisioners::Disable_RC4,
              Provisioners::Disable_TLS1,
              Provisioners::Disable_3DES,
              Provisioners::Disable_DCOM
          ]
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
