require 'securerandom'

module Packer
  module Config
    class Azure < Base
      def builders
        []
      end

      def provisioners
        []
      end
    end
  end
end
