#!/usr/bin/env ruby

# A tool to compare catalogs that have been generated via puppet master --compile
#
# Contact:
# R.I.Pienaar <rip@devco.net> - www.devco.net - @ripienaar

require 'puppet'
require 'yaml'
require 'facter'
require 'pp'
require 'fileutils'
require 'digest/md5'

# helper methods
require 'preprocessor'
require 'comparer'

################# main program starts here #######################

Puppet.parse_config
if Puppet.version =~ /^([0-9]+[.][0-9]+)[.][0-9]+/
    @version = $1

    unless ["0.24", "0.25", "2.6", "2.7", "3.0"].include?(@version)
        puts("Don't know how to compare catalogs for version #{Puppet.version}. Only 0.24, 0.25, 2.6, and 2.7 are supported")
        exit 1
    end
else
    puts("Could not figure out version from #{Puppet.version}")
    exit 1
end

if ARGV.size == 2
    FROM = ARGV[0]
    TO = ARGV[1]
else
    puts "Please specify two catalogs to compare"
    exit 1
end

from = []
to   = []
{ FROM => from, TO => to}.each do |r,v|
    unless File.exist?(r)
        puts "Cannot find resources in #{r}"
        exit 1
    end
    
    case File.extname(r)
    when '.yaml'
      tmp = YAML.load(File.read(r))
    when '.marshal'
      tmp = Marshal.load(File.read(r))
    when '.pson'
      tmp = PSON.load(File.read(r))
    end
    
    if @version == "0.24"
      convert24(tmp, v)
    else
      convert25(tmp, v)
    end
end

titles = {}
titles[:to] = extract_titles(to)
titles[:from] = extract_titles(from)

puts "Resource counts:"
puts "\tOld: #{titles[:from].size}"
puts "\tNew: #{titles[:to].size}"
puts

puts "Resource title diffs:"
print_resource_diffs(titles[:to], titles[:from])
puts

compare_resources(from, to)


