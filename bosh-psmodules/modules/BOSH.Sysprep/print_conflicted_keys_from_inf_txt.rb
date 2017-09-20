def print_section_summary(sections)
  sections.each do |x|
    section_name = x.split("\r\n").first
    section_size = x.split("\r\n").size - 1
    puts "section: #{section_name}  size: #{section_size}" 
  end
end


target = 'GptTmpl.inf' #filename of the target
destination = 'GptTmpl-utf8.txt'
`iconv -f UTF-16LE -t UTF-8 #{target} > #{destination}`

contents = File.read destination, encoding: 'bom|utf-8'
contents_by_section = contents.split(/(?=\[.+\])/)

puts "found #{contents_by_section.size} sections"

print_section_summary(contents_by_section)

puts "removing dups"

contents_by_section.map! do |section|
  elements = section.split "\r\n"
  title = elements[0]
  elements = elements[1..-1]
  title + "\r\n" + elements.uniq.join("\r\n")
end
print_section_summary(contents_by_section)

puts "listing conflicts"
contents_by_section.each do |section|
  elements = section.split "\r\n"
  title = elements[0]
  elements = elements[1..-1]

  grouped = elements.group_by {|x| x.split("=")[0]}
  dups = grouped.keys.select {|k| grouped[k].size > 1}

  if(dups.nil?)
    puts "found 0 conflicts in section #{title}"
  else
    puts "found #{dups.size} conflicts in section #{title}"
    dups.each {|x| puts x}
  end
end
