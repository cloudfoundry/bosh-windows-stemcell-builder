namespace :package do
		desc 'Package all of the manifest amis into a single tar file'
				task :aggregate_aws_amis do
					output_directory = File.absolute_path("bosh-windows-stemcell")
					FileUtils.mkdir_p(output_directory)

					amis_path = Stemcell::Builder::validate_env_dir('AMIS_PATH') # "../bosh-windows-stemcell"
					Stemcell::Packager.aggregate_the_amis(amis_path, output_directory)
				end
		end
end
