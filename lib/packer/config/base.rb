require 'securerandom'

module Packer
  module Config
    class Base
      def dump
        JSON.dump(
          'builders' => builders,
          'provisioners' => provisioners
        )
      end
    end
  end
end
