require 'stemcell/publisher/azure'

describe Stemcell::Publisher::Azure do
  describe '#print_publishing_instructions' do
    before(:each) do
      version = 'some-version'
      sku = '2012r2'
      azure_storage_account = 'some-azure_storage_account'
      azure_storage_access_key = 'some-azure_storage_access_key'
      azure_tenant_id = 'some-azure-tenant-id'
      azure_client_id = 'some-azure-client-id'
      azure_client_secret = 'some-azure-client-secret'
      container_name = 'some-container-name'
      container_path = 'some-container-path'

      @publisher = Stemcell::Publisher::Azure.new(
        version: version, sku: sku, azure_storage_account: azure_storage_account,
        azure_storage_access_key: azure_storage_access_key, azure_tenant_id: azure_tenant_id, azure_client_id: azure_client_id,
        azure_client_secret: azure_client_secret, container_name: container_name, container_path: container_path
      )
      # Stub azure cli invocation
      sas_response =
<<-HEREDOC
{
  "sas": "some-sas",
  "url": "https://storageaccount.blob.core.windows.net/containername?some-sas"
}
HEREDOC

      allow(@publisher).to receive(:create_azure_sas).and_return sas_response
    end

    it 'prints instructions for publishing azure image' do
      instructions = <<END
Please login to https://cloudpartner.azure.com
* Click "BOSH Azure Windows Stemcell"
* Click SKUs -> 2012r2
* Click "+ New VM image" at the bottom
* Input version "some-version" and OS VHD URL "https://storageaccount.blob.core.windows.net/containername/some-container-path?some-sas"
* Save and click Publish! Remember to click Go Live (in status tab) after it finishes!!
END
      expect{@publisher.print_publishing_instructions}.
        to output(instructions).to_stdout
    end
  end
end

