require 'tempfile'
require 'json'
require 'English'

module Packer
  class Runner
    class ErrorInvalidConfig < RuntimeError
    end

    def initialize(config)
      @config = config
    end

    def run(command, args)
      config_file = Tempfile.new('')
      config_file.write(JSON.dump(@config))

      args_combined = ''
      args.each do |name, value|
        args_combined += "#{name} #{value}"
      end

      `packer #{command} #{args_combined} #{config_file.path}`
      !$CHILD_STATUS.exitstatus
    end
  end
end
