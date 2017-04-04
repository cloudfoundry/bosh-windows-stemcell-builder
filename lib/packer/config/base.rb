require 'securerandom'

module Packer
  module Config
    class Base
      def pre_provisioners
        [
          Provisioners::BOSH_PSMODULES,
          Provisioners::NEW_PROVISIONER,
          Provisioners::INSTALL_CF_FEATURES,
          Provisioners::PROTECT_CF_CELL,
        ]
      end
      def post_provisioners
        [
          Provisioners::COMPRESS_DISK,
          Provisioners::CLEAR_PROVISIONER
        ]
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
