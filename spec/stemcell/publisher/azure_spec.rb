require 'stemcell/publisher/azure'

describe Stemcell::Publisher::Azure do
	let(:response){
		<<-HEREDOC
{
	"Offer": {
		"VirtualMachineImagesByServicePlan": {
			"2012r2": {
				"OperatingSystemName": "Windows Server 2012R2",
				"OperatingSystemFamily": "windows",
				"RecommendedVmSizes": [
					"d2-standard-v2",
					"d3-standard-v2",
					"d4-standard-v2"
				],
				"IsLocked": true,
				"PortRules": [],
				"VirtualMachineImages": [
					{
						"VersionId": "1.0.1",
						"VersionLabel": "1.0.1",
						"OsImageUrl": "https://koalapremiumstore.blob.core.windows.net/system/Microsoft.Compute/Images/packer-test/stemcell-osDisk.48d0cb66-bf30-4e0d-8106-774f1fda6fed.vhd?sr=c&sv=2016-05-31&ss=b&srt=co&sp=rl&se=2018-03-20T19:22:16Z&st=2017-03-07T11:22:16Z&spr=https&sig=JWjyPqKjg9cVRUYeeiLpsCyOrvdfIU%2FcTNg7Qg4%2FFNc%3D",
						"IsLocked": true,
						"DataDiskUrlsByLunNumber": {}
					},
					{
						"VersionId": "1.0.3",
						"VersionLabel": "1.0.3",
						"OsImageUrl": "https://devenvdisks477.blob.core.windows.net/system/Microsoft.Compute/Images/boshtest/cfstem-osDisk.f883362e-1c70-491c-abc4-c90a7d0f4dcc.vhd?sr=c&sv=2016-05-31&ss=b&srt=co&sp=rl&se=2018-03-28T23:33:58Z&st=2017-03-14T15:33:58Z&spr=https&sig=l%2Fhu1slbg3x5KooIQUWWJgbeWHDREwJ2hMAnQU6sBD8%3D",
						"IsLocked": true,
						"DataDiskUrlsByLunNumber": {}
					},
					{
						"VersionId": "1.0.4",
						"VersionLabel": "1.0.4",
						"OsImageUrl": "https://koalapremiumstore.blob.core.windows.net/system/Microsoft.Compute/Images/packer-test/stemcell-osDisk.e20b8629-838f-4c4b-b16c-44a3a74992f4.vhd?sr=c&sv=2016-05-31&ss=b&srt=co&sp=rl&se=2018-03-31T22:35:08Z&st=2017-03-17T14:35:08Z&spr=https&sig=6iuIJfm5oGZ8pAzLZSyimAUpUrT%2FEIbxeuPfPiaH7XQ%3D",
						"IsLocked": false,
						"DataDiskUrlsByLunNumber": {}
					}
				]
			}
		},
		"MarketingDetails": {
			"en-US": {
				"Title": "BOSH Azure Windows Stemcell",
				"Summary": "BOSH Azure Windows Stemcell",
				"LongSummary": "Curabitur mattis odio nec nibh porta elementum.",
				"HtmlDescription": "BOSH Azure Windows Stemcell",
				"ServicePlanMarketingDetails": [
					{
						"ServicePlanNaturalIdentifier": "2012r2",
						"Title": "BOSH Azure Windows Stemcell",
						"Summary": "Cras eget laoreet ex. Vestibulum tincidunt tempus nisl eget condimentum.",
						"Description": "Nunc non nulla risus. Suspendisse potenti. Donec id orci feugiat metus dignissim placerat. Vestibulum placerat, felis eget rutrum interdum, neque ex molestie est, at mollis ante nibh at sapien. Vivamus venenatis dictum magna et bibendum. Fusce dictum nunc leo, vitae vestibulum nisi vehicula vitae. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Nam et sapien sapien. Phasellus eu ex ac ligula iaculis placerat eu sit amet tellus. Curabitur ut ante sagittis, dictum purus vitae, volutpat mi. Fusce pharetra viverra rhoncus."
					}
				]
			}
		},
		"Categories": [],
		"ServicePlanDetails": {
			"2012r2": {
				"HideSku": false,
				"WasEverListed": true,
				"CloudTypes": [
					"PublicAzure"
				]
			}
		}
	},
	"Status": {
		"production": {
			"State": "InProgress",
			"Steps": [
				{
					"PercentCompleted": 100,
					"StartDateTimeOffset": "2017-04-03T13:36:17.4519996+00:00",
					"Failures": [],
					"StepNames": {
						"en-us": "2012r2: AzureCvs - Content validation completed."
					}
				},
				{
					"PercentCompleted": 100,
					"StartDateTimeOffset": "2017-04-03T13:37:35.3991444+00:00",
					"Failures": [],
					"StepNames": {
						"en-us": "2012r2: CertifyVM - Certification completed successfully."
					}
				},
				{
					"PercentCompleted": 0,
					"StartDateTimeOffset": "2017-04-03T13:36:16.6985651+00:00",
					"Failures": [],
					"StepNames": {
						"en-us": "2012r2: ProvisionVM - This step has not started yet."
					}
				},
				{
					"PercentCompleted": 0,
					"StartDateTimeOffset": "2017-04-03T13:36:16.966303+00:00",
					"Failures": [],
					"StepNames": {
						"en-us": "2012r2: PackageVM - This step has not started yet."
					}
				}
			]
		},
		"staging": {
			"State": "Staged"
		}
	}
}
		HEREDOC
	}
	describe '.json' do
		before(:each) do
			vm_to_add = {version: 'some-version', image_url: 'some-image-url'}
			@actual = Stemcell::Publisher::Azure::json(response, vm_to_add)
		end

		it 'contains the Offer contents' do
			expect(@actual['VirtualMachineImagesByServicePlan']).not_to be_nil
		end

		it 'adds the latest VM to VirtualMachineImages' do
			old_images = JSON.parse(response)['Offer']['VirtualMachineImagesByServicePlan']['2012r2']['VirtualMachineImages']
			new_images = @actual['VirtualMachineImagesByServicePlan']['2012r2']['VirtualMachineImages']
			expect(new_images.size).to eq(old_images.size+1)

			new_vm = new_images.last
			expect(new_vm['VersionId']).to eq('some-version')
			expect(new_vm['VersionLabel']).to eq('some-version')
			expect(new_vm['OsImageUrl']).to eq('some-image-url')
			expect(new_vm['isLocked']).to eq(false)
			expect(new_vm['DataDiskUrlsByLunNumber']).to eq({})
		end
	end

	describe '.publish' do
		before(:each) do
			@url = "https://www.google.com/"
			@api_key = "API_KEY"
			@headers = {
				'Accept': 'application/json',
				'Authorization': "WAMP apikey=#{@api_key}",
				'X-Protocol-Version': '2',
				'Content-Type': 'application/json'
			}
			@vm_to_add = {version: 'some-version', image_url: 'some-image-url'}
			stub_request(:get, @url).
				with(headers: @headers).
				to_return(status: 200, body: response, headers: {})
			stub_request(:post, @url+'update')
			stub_request(:post, @url+'stage')
		end

		it 'does not print the API key to stdout or stderr' do
			expect{Stemcell::Publisher::Azure::publish(@vm_to_add, @api_key, @url)}.
				to_not output(/#{@api_key}/).to_stdout
			expect{Stemcell::Publisher::Azure::publish(@vm_to_add, @api_key, @url)}.
				to_not output(/#{@api_key}/).to_stderr
		end

		it 'invokes the Azure publisher API' do
			Stemcell::Publisher::Azure::publish(@vm_to_add, @api_key, @url)

			assert_requested(:get, @url) do |req|
				headers = req.headers
				(headers['Accept'] == 'application/json') &&
				(headers['Authorization'] ==  "WAMP apikey=#{@api_key}") &&
				(headers['X-Protocol-Version'] == '2') &&
				(headers['Content-Type'] == 'application/json')
			end
			assert_requested(:post, @url+'update') do |req|
				headers = req.headers
				(headers['Accept'] == 'application/json') &&
				(headers['Authorization'] ==  "WAMP apikey=#{@api_key}") &&
				(headers['X-Protocol-Version'] == '2') &&
				(headers['Content-Type'] == 'application/json')

				body = req.body
				expected_body = URI.encode_www_form(Stemcell::Publisher::Azure::json(response, @vm_to_add))
				body == expected_body
			end
			assert_requested(:post, @url+'stage') do |req|
				headers = req.headers
				(headers['Accept'] == 'application/json') &&
				(headers['Authorization'] ==  "WAMP apikey=#{@api_key}") &&
				(headers['X-Protocol-Version'] == '2') &&
				(headers['Content-Type'] == 'application/json')
			end
		end
	end
end

