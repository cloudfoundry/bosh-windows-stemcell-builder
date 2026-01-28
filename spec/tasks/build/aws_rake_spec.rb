require "spec_helper"

RSpec.describe "AWS Rake" do
  context "validate_ami" do
    let(:task) { Rake::Task["build:validate_ami"] }
    let(:task_output) { [] }

    before do
      task.reenable
      allow(Stemcell::Builder).to receive(:validate_env_dir).with("VERSION_DIR").and_return("version_dir")
      allow(Stemcell::Builder).to receive(:validate_env_dir).with("AMIS_DIR").and_return("amis_dir")
      allow(File).to receive(:read).with("version_dir/number").and_return("1709.10.43-build.1")
      allow(File).to receive(:read).with("amis_dir/packer-output-ami-1709.10.43-build.1.txt").and_return('{"region":"us-east-1","ami_id":"ami-1475586e"}')

      allow(Output).to receive(:say) do |something|
        task_output << something
      end
    end

    it "should finish with no error when ami becomes available" do
      allow(Executor).to receive(:exec_command).and_return('{"Images":[{"ID":"ami-1475586e","State":"available"}]}')
      expect { task.invoke }.not_to raise_error
      expect(task_output).to eq(["Waiting for ami-1475586e to become available...", "AMI ami-1475586e is available"])
    end

    it "should raise error when AWS fails to create ami" do
      allow(Executor).to receive(:exec_command).and_return('{"Images":[{"ID":"ami-1475586e","State":"failed"}]}')
      expect { task.invoke }.to raise_error(FailedAMIValidationError)
      expect(task_output).to eq(["Waiting for ami-1475586e to become available...", "AWS failed to create AMI ami-1475586e"])
    end

    it "should finish with no error when ami is pending for a while and then available" do
      allow(Executor).to receive(:exec_command).and_return(
        '{"Images":[]}',
        '{"Images":[]}',
        '{"Images":[]}',
        '{"Images":[{"ID":"ami-1475586e","State":"available"}]}'
      )

      expect(Executor).to receive(:exec_command).exactly(4).times
      expect { task.invoke }.not_to raise_error
      expect(task_output).to eq(["Waiting for ami-1475586e to become available...", "AMI ami-1475586e is available"])
    end
  end
end
