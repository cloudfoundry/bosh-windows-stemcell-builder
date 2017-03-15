require 'open3'

def exec_command(cmd)
  STDOUT.sync = true
  puts "Running: #{cmd}"
  Open3.popen2(cmd) do |stdin, out, wait_thr|
    out.each_line do |line|
      puts line
    end
    exit_status = wait_thr.value
    if exit_status != 0
      raise "error running command: #{cmd}"
    end
  end
end
