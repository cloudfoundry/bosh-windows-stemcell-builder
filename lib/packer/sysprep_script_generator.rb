# frozen_string_literal: true

module Packer
  # Builds AWS EC2 user_data or GCP sysprep-specialize-script from the repo copy of
  # modules/BOSH.WinRM/BOSH.WinRM.psm1 inlined into the script (no mutable remote fetch).
  class SysprepScriptGenerator
    GCP_METADATA_MAX_BYTES = 256 * 1024
    EC2_USER_DATA_MAX_BYTES = 16 * 1024
    STEMCELL_BUILDER_DIR = File.expand_path("../../..", __FILE__)

    WRITE_LOG_PS = <<~'PS'
      function Write-Log
      {
          Param (
              [Parameter(Mandatory = $True, Position = 1)][string]$Message,
              [string]$LogFile = "C:\provision\log.log"
          )

          $LogDir = (split-path $LogFile -parent)
          If ((Test-Path $LogDir) -ne $True)
          {
              New-Item -Path $LogDir -ItemType Directory -Force
          }

          $msg = "{0} {1}" -f (Get-Date -Format o), $Message
          Add-Content -Path $LogFile -Value $msg -Encoding 'UTF8'
          Write-Host $msg
      }
    PS

    def initialize(stemcell_builder_dir: STEMCELL_BUILDER_DIR)
      @stemcell_builder_dir = stemcell_builder_dir
      @module_path = File.join(@stemcell_builder_dir, "modules", "BOSH.WinRM", "BOSH.WinRM.psm1")
    end

    def content(iaas:)
      iaas_sym = iaas.to_sym if iaas.respond_to?(:to_sym)
      unless iaas_sym == :gcp || iaas_sym == :aws
        raise ArgumentError, "unsupported iaas: #{iaas.inspect} (expected :gcp or :aws)"
      end

      case iaas_sym
      when :gcp
        body = build_core_powershell
        assert_size!(body, max_bytes: GCP_METADATA_MAX_BYTES, label: "GCE sysprep-specialize-script-ps1 metadata")
        body
      when :aws
        script_body = [build_core_powershell, aws_additional_powershell].join("\n\n")
        wrapped = wrap_aws_user_data_xml(script_body)
        assert_size!(wrapped, max_bytes: EC2_USER_DATA_MAX_BYTES, label: "EC2 user_data")
        wrapped
      end
    end

    private

    def aws_additional_powershell
      "Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope LocalMachine"
    end

    def wrap_aws_user_data_xml(inner_script)
      "<powershell>\n#{inner_script}\n</powershell>"
    end

    def build_core_powershell
      module_source = File.read(@module_path, encoding: Encoding::UTF_8).rstrip

      parts = []
      parts << WRITE_LOG_PS.rstrip
      parts << ""
      parts << module_source
      parts << ""
      parts << 'Write-Log "Invoking WinRM"'
      parts << "Enable-WinRM"

      parts.join("\n")
    end

    def assert_size!(string, max_bytes:, label:)
      size = string.bytesize
      return if size <= max_bytes

      raise ArgumentError,
        "#{label} is #{size} bytes (limit #{max_bytes} bytes; source module: #{@module_path})"
    end
  end
end
