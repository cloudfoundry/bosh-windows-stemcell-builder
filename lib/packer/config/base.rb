require 'securerandom'

module Packer
  module Config
    class Base
      def self.pre_provisioners(os, skip_windows_update: false)
        if os == 'windows2012R2'
          pre = [
            Provisioners::BOSH_PSMODULES,
            Provisioners::NEW_PROVISIONER,
            Provisioners::INSTALL_CF_FEATURES
          ]
          install_windows_updates = if skip_windows_update then [] else [Provisioners.install_windows_updates] end
          post = [Provisioners::PROTECT_CF_CELL]

          pre + install_windows_updates + post
        elsif os == 'windows2016'
          pre = [
            Provisioners::BOSH_PSMODULES,
            Provisioners::NEW_PROVISIONER,
            Provisioners::INSTALL_CONTAINERS,
            Provisioners::INSTALL_CF_FEATURES
          ]
          install_windows_updates = if skip_windows_update then [] else [Provisioners.install_windows_updates] end
          post = [Provisioners::PROTECT_CF_CELL]

          pre + install_windows_updates + post
        end
      end

      def self.post_provisioners(iaas)
        provisioners = [
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

      def dump
        JSON.dump(
          'builders' => builders,
          'provisioners' => provisioners
        )
      end
    end
  end
end
