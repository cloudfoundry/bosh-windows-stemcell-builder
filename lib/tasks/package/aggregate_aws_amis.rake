namespace :package do
		desc 'Package all of the manifest amis into a single tar file'
				task :aggregate_aws_amis do
					amis_path = Stemcell::Builder::validate_env_dir('AMIS_PATH')
					Stemcell::Packager.aggregate_the_amis(amis_path)
				end
		end
end
