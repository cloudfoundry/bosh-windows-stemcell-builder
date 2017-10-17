require 'open3'

class Executor
  def self.exec_command(cmd)
    STDOUT.sync = true
    puts "Running: #{cmd}"

    ret = ''

    Open3.popen2(cmd) do |stdin, out, wait_thr|
      out.each_line do |line|
        ret += line
        puts line
      end
      exit_status = wait_thr.value
      if exit_status != 0
        raise "error running command: #{cmd}"
      end
    end

    return ret
  end
  def self.exec_command_no_output(cmd)
    STDOUT.sync = true
    Open3.popen2(cmd) do |stdin, out, wait_thr|
      exit_status = wait_thr.value
      if exit_status != 0
        raise "error running command: #{cmd}"
      end
    end
  end
end

def exec_command(cmd)
  Executor.exec_command(cmd)
end
def exec_command_no_output(cmd)
  Executor.exec_command_no_output(cmd)
end
