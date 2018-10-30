require 'stemcell/publisher/azure'

describe Stemcell::Publisher::Azure do
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
  end

  describe '#print_publishing_instructions' do
    before(:each) do
      Timecop.freeze
    end

    after(:each) do
      Timecop.return
    end

    it 'prints instructions for publishing azure image' do
      expected_login_command = "az login --username #{@publisher.azure_client_id} --password #{@publisher.azure_client_secret} --service-principal --tenant #{@publisher.azure_tenant_id}"
      validFrom = (Time.now.utc - 1.day).iso8601
      validTo = (Time.now.utc + 2.year).iso8601
      expected_sas_command = "az storage container generate-sas --name #{@publisher.container_name} --permissions rl --account-name #{@publisher.azure_storage_account} --account-key #{@publisher.azure_storage_access_key} --start #{validFrom} --expiry #{validTo}"
      expected_url_command = "az storage blob url --container-name #{@publisher.container_name} --name #{@publisher.container_path} --account-name #{@publisher.azure_storage_account} --account-key #{@publisher.azure_storage_access_key}"

      expected_instructions = <<END
Please login to https://cloudpartner.azure.com
* Click "BOSH Azure Windows Stemcell"
* Click SKUs -> 2012r2
* Click "+ New VM image" at the bottom
* Input version "some-version" and OS VHD URL "vhd-url?sas-code"
* Save and click Publish! Remember to click Go Live (in status tab) after it finishes!!
END

      expect(Executor).to receive(:exec_command_no_output).with(expected_login_command)
      expect(Executor).to receive(:exec_command).once.with(expected_url_command).and_return("\"vhd-url\"\n")
      expect(Executor).to receive(:exec_command).once.with(expected_sas_command).and_return("\"sas-code\"\n")
      expect {@publisher.print_publishing_instructions}.
        to output(expected_instructions).to_stdout
    end
  end

  describe '#copy_vhd_to_published_storage_account' do
    it 'copies vhd from unpublished storage account to published storage account' do
      source_storage_account = "source-account"
      source_storage_key = "source-key"
      expected_login_command = "az login --username #{@publisher.azure_client_id} --password #{@publisher.azure_client_secret} --service-principal --tenant #{@publisher.azure_tenant_id}"
      expected_copy_command = "az storage blob copy start --source-account-key \"#{source_storage_key}\" --source-account-name \"#{source_storage_account}\" --source-container \"system\" --source-blob \"#{@publisher.container_path}\" --account-name \"#{@publisher.azure_storage_account}\" --destination-container \"system\" --destination-blob \"#{@publisher.container_path}\""
      expect(Executor).to receive(:exec_command_no_output).once.ordered.with(expected_login_command)
      expect(Executor).to receive(:exec_command_no_output).once.ordered.with(expected_copy_command)

      @publisher.copy_from_storage_account(source_storage_account, source_storage_key)
    end
  end
end

