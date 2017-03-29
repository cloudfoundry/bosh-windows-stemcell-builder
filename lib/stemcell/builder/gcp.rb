module Stemcell
  class Builder
    class Gcp < Base
      def initialize(account_json:, source_image:, **args)
        @account_json = account_json
        @project_id = JSON.parse(@account_json)['project_id']
        @source_image = source_image
        super(args)
      end

      def build
        image_url = run_packer
        manifest = Manifest::Gcp.new(@version, @os, image_url).dump
        update_list = File.join(@output_directory, 'updates.txt')
        super(iaas: 'google-kvm', is_light: true, image_path: '', manifest: manifest, update_list: update_list)
      end

      private
        def packer_config
          Packer::Config::Gcp.new(@account_json, @project_id, @source_image, @output_directory
                                 ).dump
        end

        def parse_packer_output(packer_output)
          image_name = nil
          packer_output.each_line do |line|
            puts line
            image_name ||= parse_image_name(line)
          end
          get_image_url(image_name)
        end

        def parse_image_name(line)
          if line.include?(",artifact,0,id,")
            return line.split(",").last.chomp
          end
        end

        def get_image_url(image_name)
          "https://www.googleapis.com/compute/v1/projects/#{@project_id}/global/images/#{image_name}"
        end
    end
  end
end
