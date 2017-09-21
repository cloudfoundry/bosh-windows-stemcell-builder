#!/usr/bin/env ruby

class Infs
  def self.from_string(s)
    Inf.from_string_array(s.split(/(?=\[.+\])/))
  end
end

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
    Inf.new(name, trim_contents.uniq {|text| text.split('=')[0].downcase + text.split('=')[1..-1].join('')})
  end

  def sort()
    Inf.new(name, contents.sort)
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

def convert_to_utf8(name)
  `iconv -f UTF-16LE -t UTF-8 #{name} > /tmp/registry-tmp`
  File.read '/tmp/registry-tmp', encoding: 'bom|utf-8'
end

def merge(a, b)
  a_no_comment = a.split("\r\n").reject {|x| x.strip.gsub(/^;.*/,'').empty?}.join("\r\n").strip
  b_no_comment = b.split("\r\n").reject {|x| x.strip.gsub(/^;.*/,'').empty?}.join("\r\n").strip

  a_infs = Infs.from_string(a_no_comment)
  b_infs = Infs.from_string(b_no_comment)

  (a_infs + b_infs).group_by {|x| x.name}.map {|section_name,infs| Inf.new(section_name, infs.map{|x| x.contents}.flatten)}
end

target = 'GptTmpl.inf' #filename of the target
destination = 'GptTmpl-utf8.txt'
`iconv -f UTF-16LE -t UTF-8 #{target} > #{destination}`

a_contents = convert_to_utf8('GptTmpl-ms-baseline.inf')
b_contents = convert_to_utf8('GptTmpl-cis-baseline.inf')

puts "merged"
merged = merge(a_contents, b_contents)

print_section_summary(merge(a_contents, b_contents))

puts "removing dups"

unique = merged.map do |section|
  section.uniq
end

sorted = unique.map do |section|
  section.sort
end

print_section_summary(sorted)

puts "listing conflicts"
sorted.each do |section|
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

new_file = 'GptTmpl-merged.inf'
File.write new_file, sorted.map{|section| section.name + "\n" + section.contents.join("\n")}.join("\n")
puts "merged files with uniques removed outputted to #{new_file}"
