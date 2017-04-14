require 'securerandom'

module Packer
  module Config
    class Base
      def pre_provisioners
        [
          Provisioners::BOSH_PSMODULES,
          Provisioners::NEW_PROVISIONER,
          Provisioners::INSTALL_CF_FEATURES,
          Provisioners.install_windows_updates,
          Provisioners::PROTECT_CF_CELL
        ]
      end

      def post_provisioners(iaas)
        provisioners = [
          Provisioners::OPTIMIZE_DISK,
          Provisioners::COMPRESS_DISK,
          Provisioners::CLEAR_PROVISIONER
        ]

        if iaas.downcase != 'vsphere'
          provisioners += Provisioners.sysprep_shutdown(iaas)
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
