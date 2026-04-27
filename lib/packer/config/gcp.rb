require "securerandom"

module Packer
  module Config
    class Gcp
      # GCE instance metadata limits inline script payload size (~256 KiB).
      SYSPREP_SPECIALIZE_SCRIPT_METADATA_MAX_BYTES = 256 * 1024

      def initialize(
        account_json:,
        project_id:,
        source_image:,
        image_family:,
        os:,
        output_directory:,
        version:,
        vm_type:, vm_prefix: "",
        mount_ephemeral_disk: false,
        root_disk_size: 32,
        omit_external_ip: false,
        vm_tags: ["winrm"],
        network: nil,
        network_project_id: nil,
        subnetwork: nil
      )
        @account_json = account_json
        @project_id = project_id
        @source_image = source_image
        @image_family = image_family
        @os = os
        @output_directory = output_directory
        @version = version
        @vm_prefix = vm_prefix.empty? ? "packer" : vm_prefix
        @mount_ephemeral_disk = mount_ephemeral_disk
        @root_disk_size = root_disk_size
        @omit_external_ip = omit_external_ip
        @vm_tags = vm_tags
        @vm_type = vm_type
        @network = network
        @network_project_id = network_project_id
        @subnetwork = subnetwork
      end

      def builders
        stemcell_builder_dir = File.expand_path("../../../../", __FILE__)
        setup_winrm_path = File.join(stemcell_builder_dir, "scripts", "gcp", "setup-winrm.ps1")
        sysprep_script_ps1 = File.read(setup_winrm_path)
        if sysprep_script_ps1.bytesize > SYSPREP_SPECIALIZE_SCRIPT_METADATA_MAX_BYTES
          raise ArgumentError,
            "sysprep-specialize-script-ps1 content from #{setup_winrm_path} is #{sysprep_script_ps1.bytesize} bytes, " \
            "which exceeds the GCE metadata inline script limit of #{SYSPREP_SPECIALIZE_SCRIPT_METADATA_MAX_BYTES} bytes"
        end

        [
          {
            "type" => "googlecompute",
            "credentials_json" => @account_json,
            "project_id" => @project_id,
            "tags" => @vm_tags,
            "source_image" => @source_image,
            "image_family" => @image_family,
            "zone" => "us-west1-c",
            "disk_size" => @root_disk_size,
            "image_name" => "packer-#{Time.now.to_i}",
            "machine_type" => @vm_type,
            "network" => @network,
            "network_project_id" => @network_project_id,
            "subnetwork" => @subnetwork,
            "omit_external_ip" => @omit_external_ip,
            "use_internal_ip" => @omit_external_ip,
            "communicator" => "winrm",
            "winrm_username" => "winrmuser",
            "winrm_use_ssl" => false,
            "winrm_timeout" => "1h",
            "state_timeout" => "10m",
            "metadata" => {
              "sysprep-specialize-script-ps1" => sysprep_script_ps1,
              "name" => "#{@vm_prefix}-#{Time.now.to_i}"
            }.compact_blank!
          }
        ]
      end

      def provisioners
        Provisioner.new(@os, "gcp", @mount_ephemeral_disk, @version).dump
      end

      def dump
        JSON.dump(
          "builders" => builders,
          "provisioners" => provisioners
        )
      end
    end
  end
end
