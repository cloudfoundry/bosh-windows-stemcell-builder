#!/usr/bin/env ruby

require 'fileutils'

require_relative '../lib/exec_command'

Dir.chdir 'stemcell-builder' do
  exec_command('bundle install')
  exec_command('rake test:run_bwats')
end
