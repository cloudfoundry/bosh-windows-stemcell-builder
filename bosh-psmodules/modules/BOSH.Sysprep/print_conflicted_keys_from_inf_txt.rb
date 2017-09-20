class Inf
  attr_accessor :name
  attr_accessor :contents

  def initialize(name, contents)
    @name = name
    @contents = contents
  end

  def self.from_string_array(sections)
    sections.map do |x|
      contents = x.split("\r\n")
      section_name = contents.first
      section_contents = contents[1..-1]

      Inf.new(section_name, section_contents)
    end
  end

  def uniq()
    trim_contents = contents.map { |x| x.strip }
    Inf.new(name, trim_contents.uniq)
  end

  def size()
    @contents.size
  end

  def summary()
    "section: #{@name} size: #{size}"
  end
end

def print_section_summary(sections)
  sections.each do |x|
    puts x.summary
  end
end

target = 'GptTmpl.inf' #filename of the target
destination = 'GptTmpl-utf8.txt'
`iconv -f UTF-16LE -t UTF-8 #{target} > #{destination}`

contents = File.read destination, encoding: 'bom|utf-8'
contents_by_section = Inf.from_string_array(contents.split(/(?=\[.+\])/))

puts "found #{contents_by_section.size} sections"

print_section_summary(contents_by_section)

puts "removing dups"

contents_by_section.map do |section|
  section.uniq
end

print_section_summary(contents_by_section)

puts "listing conflicts"
contents_by_section.each do |section|
  elements = section.contents
  title = section.name

  grouped = elements.group_by {|x| x.split("=")[0]}
  dups = grouped.keys.select {|k| grouped[k].size > 1}

  if(dups.nil?)
    puts "found 0 conflicts in section #{title}"
  else
    puts "found #{dups.size} conflicts in section #{title}"
    dups.each {|x| puts x}
  end
end
