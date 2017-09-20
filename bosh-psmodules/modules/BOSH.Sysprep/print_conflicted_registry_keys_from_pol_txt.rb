target = 'registry.txt' #filename of the target 
destination = 'registry-utf8.txt'
`iconv -f UTF-16LE -t UTF-8 #{target} > #{destination}`

before_uniq = (File.read destination).split("\r\n\r\n").sort

puts "before uniq: #{before_uniq.size}"
after_uniq = before_uniq.uniq
puts "after uniq: #{after_uniq.size}"

library = after_uniq.group_by {|x| x.split("\r\n")[1..2].join('\\')}
dups = library.keys.find {|k| library[k].size > 1}

if(dups.nil?)
  puts "found 0 conflicts"
else
  puts "found #{dups.size} conflicts"
  dups.each {|x| puts x}
end
