module Stemcell
  class Builder
    class PackerFailure < RuntimeError
    end

    class Base
      def initialize(os:, output_directory:, version:, agent_commit:, packer_vars:)
        @os = os
        @output_directory = output_directory
        @version = version
        @agent_commit = agent_commit
        @packer_vars = packer_vars
      end

      def build(iaas:, is_light:, image_path:, manifest:)
        apply_spec = ApplySpec.new(@agent_commit).dump
        Packager.package(
          iaas: iaas,
          os: @os,
          is_light: is_light,
          version: @version,
          image_path: image_path,
          manifest: manifest,
          apply_spec: apply_spec,
          output_directory: @output_directory
        )
      end

      private

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

      def exec_command(cmd)
        `#{cmd}`
        raise "command '#{cmd}' failed" unless $?.success?
      end

      def parse_packer_output(packer_output)
        packer_output.each_line do |line|
          puts line
        end
      end
    end
  end
end
