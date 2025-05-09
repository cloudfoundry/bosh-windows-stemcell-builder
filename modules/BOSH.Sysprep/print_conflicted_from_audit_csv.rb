#!/usr/bin/env ruby

class AuditFile
  attr_accessor :header
  attr_accessor :contents

  def initialize(header, contents)
    @header = header
    @contents = contents
  end

  def self.from_string(s)
    lines = s.split "\r\n"
    header = lines[0]
    contents = lines[1..-1]

    AuditFile.new(header, contents)
  end

  def print()
    ([header] + contents).join("\r\n")
  end

  def uniq()
    uniqed = contents.uniq do |x|
      values = x.split(',')
      keys = values[0..5].join('').downcase
      setting_value = values[6]
      keys+setting_value
    end

    AuditFile.new(header, uniqed)
  end

  def size()
    contents.size
  end
end

def merge(a, b)
  AuditFile.new(a.header, a.contents + b.contents)
end

a_file = File.read 'audit-cis.csv'
b_file = File.read 'audit-ms.csv'

a_audit = AuditFile.from_string(a_file)
b_audit = AuditFile.from_string(b_file)

puts "a has #{a_audit.size} lines"
puts "b has #{b_audit.size} lines"

merged = merge(a_audit, b_audit)
puts "after merge: #{merged.size} lines"

uniqued = merged.uniq
puts "after uniq: #{uniqued.size} lines"

grouped = uniqued.contents.group_by do |line|
  fields = line.split ','
  policy_target = fields[1].downcase
  subcategory = fields[2].downcase
  policy_target + ',' + subcategory
end

dups = grouped.keys.select {|k| grouped[k].size > 1}

if(dups.nil?)
  puts "found 0 conflicts"
else
  puts "found #{dups.size} conflicts"
  dups.each {|x| puts x}
end

merged_file = "audit-merged.csv"
File.write merged_file, uniqued.print
puts "wrote merged stuff to #{merged_file}"
