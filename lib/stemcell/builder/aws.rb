module Stemcell
  class Builder
    class Aws < Base
      def initialize(ami:, aws_access_key:, aws_secret_key:, aws_role_arn: '', vm_prefix:, **kwargs)
        @ami = ami
        @aws_access_key = aws_access_key
        @aws_secret_key = aws_secret_key
        @aws_role_arn = aws_role_arn
        @vm_prefix = vm_prefix
        super(**kwargs)
      end

      def build(amis)
        manifest = Manifest::Aws.new(@version, @os, amis).dump
        super(iaas: 'aws-xen-hvm',
              is_light: true,
              image_path: '',
              manifest: manifest,
              update_list: update_list_path
             )
      end

      def build_from_packer(ami_output_directory)
        amis = run_packer
        File.open(File.join(ami_output_directory, "packer-output-ami-#{@version}.txt"), 'w') do |f|
          f.write(amis[0].to_json)
        end
        build(amis)
      end

      private

      def packer_config
        Packer::Config::Aws.new(
          aws_access_key: @aws_access_key,
          aws_secret_key: @aws_secret_key,
          aws_role_arn: @aws_role_arn,
          region: @ami,
          output_directory: @output_directory,
          os: @os,
          version: @version,
          vm_prefix: @vm_prefix,
          mount_ephemeral_disk: @mount_ephemeral_disk
        ).dump
      end

      def parse_packer_output(packer_output)
        amis = []
        packer_output.each_line do |line|
          if !(line.include?('secret_key') || line.include?('access_key'))
            puts line
          end
          ami = parse_ami(line)
          if !ami.nil?
            amis.push(ami)
          end
        end
        amis
      end

      def parse_ami(line)
        unless line.include?(',artifact,0,id,')
          return
        end

        region_id = line.split(',').last.split(':')
        return {'region'=> region_id[0].chomp, 'ami_id'=> region_id[1].chomp}
      end
    end
  end
end
