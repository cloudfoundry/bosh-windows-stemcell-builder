require 'tempfile'
require 'json'

module Packer
  class Runner
    class ErrorInvalidConfig < Exception
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

      `packer #{command} #{config_file.path} #{args_combined}`
      return !$?.exitstatus
    end
  end
end
