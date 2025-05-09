require 'aws-sdk'
require 'azure_mgmt_resources'
require 'json'
require 'tempfile'

module DeleteVms
  class Aws
    def self.delete(vm_prefix)
      if ENV['AWS_ROLE_ARN'] && !ENV['AWS_ROLE_ARN'].empty?
        `aws configure --profile creds_account set aws_access_key_id "#{ENV['AWS_ACCESS_KEY']}"`
        `aws configure --profile creds_account set aws_secret_access_key "#{ENV['AWS_SECRET_KEY']}"`
        `aws configure --profile resource_account set source_profile "creds_account"`
        `aws configure --profile resource_account set role_arn "#{ENV['AWS_ROLE_ARN']}"`

        ENV['AWS_PROFILE'] = 'resource_account'
        ENV.delete('AWS_ACCESS_KEY')
        ENV.delete('AWS_SECRET_KEY')
      end

      puts "Deleting AWS vms with prefix #{vm_prefix}"
      regions = ENV['REGIONS'].split(',')
      regions.each do |region|
        ec2 = ::Aws::EC2::Client.new(region: region)
        reservations = ec2.describe_instances()
        instances = reservations.map { |r| r.reservations.map(&:instances) }.flatten.select do |i|
          i.tags.any? { |t| t.key == 'Name' && t.value.start_with?(vm_prefix) }
        end.map(&:instance_id)
        if instances.any?
          puts "Deleting #{instances} in region #{region}"
          ec2.terminate_instances({
            dry_run: false,
            instance_ids: instances
          })
        end
      end
    end
  end

  class Gcp
    def self.delete(vm_prefix)
      puts "Deleting GCP vms with prefix #{vm_prefix}"
      account_json = ENV['ACCOUNT_JSON']
      account_data = JSON.parse(account_json)
      account_email = account_data['client_email']

      Tempfile.create(['account','.json']) do |f|
        f.write(account_json)
        f.close
        `gcloud auth activate-service-account --quiet #{account_email} --key-file #{f.path}`
      end

      `gcloud config set project #{account_data['project_id']}`
      filter="metadata.items.key['name'][value]~'#{vm_prefix}.*'"
      instances = JSON.parse(`gcloud compute instances list --filter="#{filter}" --format=json`)
      if instances.empty?
        puts "No instances found to delete"
      else
        puts `gcloud compute instances list --filter="#{filter}"`
        `gcloud compute instances delete --quiet $(gcloud compute instances list --uri --filter="#{filter}")`
      end
    end
  end

  class Azure
    def self.delete(vm_prefix)
      puts "Deleting Azure vms with prefix #{vm_prefix}"
      token_provider = MsRestAzure::ApplicationTokenProvider.new(ENV['TENANT_ID'], ENV['CLIENT_ID'], ENV['CLIENT_SECRET'])
      credentials = MsRest::TokenCredentials.new(token_provider)
      client = ::Azure::Resources::Mgmt::V2017_05_10::ResourceManagementClient.new(credentials)
      client.subscription_id = ENV['SUBSCRIPTION_ID']
      packer_resource_groups = client.resource_groups.list.select { |g| g.name.start_with?(vm_prefix) }
      packer_resource_groups.each { |g| puts g.name; client.resource_groups.delete_async(g.name) }
      sleep(1)
    end
  end
end


if ENV['VM_PREFIX'] == ''
  throw 'Must specify a prefix for VMs to delete'
end

case ENV['IAAS']
  when 'aws'
    DeleteVms::Aws.delete(ENV['VM_PREFIX'])
  when 'gcp'
    DeleteVms::Gcp.delete(ENV['VM_PREFIX'])
  when 'azure'
    DeleteVms::Azure.delete(ENV['VM_PREFIX'])
  else
    throw "Could not find an environment to run delete"
end
