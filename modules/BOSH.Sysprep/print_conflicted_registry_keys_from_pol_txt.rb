#!/usr/bin/env ruby

def convert_to_utf8(name)
  `iconv -f UTF-16LE -t UTF-8 #{name} > /tmp/registry-tmp`
  File.read '/tmp/registry-tmp', encoding: 'bom|utf-8'
end

def merge(a, b)
  a_no_comment = a.split("\r\n").reject {|x| x[0] == ';' }.join("\r\n").strip
  b_no_comment = b.split("\r\n").reject {|x| x[0] == ';' }.join("\r\n").strip
  a_no_comment.strip + "\r\n\r\n" + b_no_comment.strip
end

registry_a_name = 'registry-cis-machine.txt'
registry_b_name = 'registry-ms-baseline-machine.txt'

registry_a_contents = convert_to_utf8(registry_a_name)
registry_b_contents = convert_to_utf8(registry_b_name)

before_uniq = merge(registry_a_contents, registry_b_contents).split("\r\n\r\n").sort

puts "before uniq: #{before_uniq.size}"
after_uniq = before_uniq.uniq do |entry|
  lines = entry.split "\r\n"
  reg_key = (lines[1] + lines[2]).downcase
  lines[0] + reg_key + lines[3]
end
puts "after uniq: #{after_uniq.size}"

library = after_uniq.group_by {|x| x.split("\r\n")[1..2].join('\\')}
dups = library.keys.select {|k| library[k].size > 1}

if(dups.nil?)
 puts "found 0 conflicts"
else
 puts "found #{dups.size} conflicts"
 dups.each {|x| puts x}
end

merged_file = "registry-merged.txt"
File.write merged_file, after_uniq.join("\r\n\r\n")
puts "wrote merged registry files with duplicates removed to #{merged_file}"
