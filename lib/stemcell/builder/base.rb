module Stemcell
  class Builder
    class PackerFailure < RuntimeError
    end

    class Base
      def initialize(os:, output_dir:, version:, agent_commit:, packer_vars:)
        @os = os
        @output_dir = output_dir
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
          output_dir: @output_dir
        )
      end

      private

        def run_packer
          packer_artifact = nil
          Packer::Runner.new(packer_config).run('build', @packer_vars) do |stdout|
            packer_artifact = parse_packer_output(stdout)
          end
          packer_artifact
        end

        def exec_command(cmd)
          `#{cmd}`
          raise "command '#{cmd}' failed" unless $?.success?
        end
    end
  end
end
