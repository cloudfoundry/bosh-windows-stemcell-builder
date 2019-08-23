class TestProvisioner
  attr_accessor :command, :source, :destination, :provisioner_type

  def self.new_file_provisioner(source, destination)
    provisioner = new
    provisioner.provisioner_type = :file
    provisioner.source = source
    provisioner.destination = destination
    provisioner
  end

  def self.new_powershell_provisioner(command)
    provisioner = new
    provisioner.provisioner_type = :powershell
    provisioner.command = command
    provisioner
  end

  def inspect
    case @provisioner_type
    when :powershell
      return "Powershell provisioner with command: '#{@command}'"
    when :file
      return "File Provisioner with source: '#{@source}' and destination: '#{@destination}'"
    end
  end

  def matches?(actual_provisioner)
    case @provisioner_type
    when :powershell
      actual_provisioner['type'] == 'powershell' &&
          actual_provisioner.has_key?('inline') &&
          actual_provisioner['inline'].find do |script_line|
            if @command.is_a?(String)
              script_line.eql? @command
            elsif @command.is_a?(Regexp)
              script_line =~ @command
            else
              raise "provisioner command neither string nor regex"
            end
          end
    when :file
      actual_provisioner['type'] == 'file' &&
          actual_provisioner['source'] == @source &&
          actual_provisioner['destination'] == @destination
    else
      false
    end
  end
end