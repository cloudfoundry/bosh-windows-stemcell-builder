module Stemcell
  class Builder
    class PackerFailure < RuntimeError
    end

    class EnvironmentValidationError < RuntimeError
    end

    def self.validate_env(var)
      raise EnvironmentValidationError.new("environment missing #{var}") unless ENV.has_key?(var)
      ENV[var]
    end

    def self.validate_env_dir(vars)
      dir = self.validate_env(vars)
      raise EnvironmentValidationError.new("directory #{dir} does not exist") unless Dir.exist?(dir)
      dir
    end

    class Base
      def initialize(os:, output_directory:, version:, agent_commit:, packer_vars:)
        @os = os
        @output_directory = output_directory
        @version = version
        @agent_commit = agent_commit
        @packer_vars = packer_vars
      end

      def build(iaas:, is_light:, image_path:, manifest:, update_list:)
        apply_spec = ApplySpec.new(@agent_commit).dump
        Packager.package(
          iaas: iaas,
          os: @os,
          is_light: is_light,
          version: @version,
          image_path: image_path,
          manifest: manifest,
          apply_spec: apply_spec,
          output_directory: @output_directory,
          update_list: update_list
        )
      end


      def run_packer
        packer_artifact = nil
        exit_status = Packer::Runner.new(packer_config).run('build', @packer_vars) do |stdout|
          packer_artifact = parse_packer_output(stdout)
        end
        if exit_status != 0
          raise PackerFailure
        end
        packer_artifact
      end

      private

      def exec_command(cmd)
        STDOUT.sync = true
        Open3.popen2(cmd) do |stdin, out, wait_thr|
          out.each_line do |line|
            puts line
          end
          exit_status = wait_thr.value
          if exit_status != 0
            raise "error running command: #{cmd}"
          end
        end
      end

      def parse_packer_output(packer_output)
        packer_output.each_line do |line|
          puts line
        end
      end

      def update_list_path
        if File.exist?(File.join(@output_directory, 'updates.txt'))
          File.join(@output_directory, 'updates.txt')
        else
          puts "'updates.txt' does not exist in #{@output_directory}"
        end
      end
    end
  end
end
