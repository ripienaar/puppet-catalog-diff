#!/usr/bin/env ruby

# A tool to compare catalogs that have been converted to our intermediate
# format using dumplocalconfig.rb
#
# Contact:
# R.I.Pienaar <rip@devco.net> - www.devco.net - @ripienaar

require 'yaml'
require 'pp'
require 'rubygems'
require 'diffy'
require 'getopt/std'

def print_help()
  puts
  puts "USAGE: diffcatalogs.rb -o <ref> -n <test> [-u]"
  puts "\t -o <ref>  the old catalog"
  puts "\t -n <test> the new catalog"
  puts "\t -u        print individual resource diffs in unified diff format"
  puts
  exit 1
end

opt = Getopt::Std.getopts("o:n:u")

if not opt["n"] or not opt["o"]
  print_help()
end
if opt["n"]
  TO=opt["n"]
end
if opt["o"]
  FROM=opt["o"]
end
if opt["u"]
  UNIFIED=true
else
  UNIFIED=false
end

[FROM, TO].each do |r|
    unless File.exist?(r)
        puts "Cannot find resources in #{r}"
        exit 1
    end
end

# Creates an array of just the resource titles
# it would be records like file["/foo"]
def extract_titles(resources)
    titles = []

    resources.each do |resource|
        titles << resource[:resource_id]
    end

    titles
end

# Make a resource into a string that looks like puppet code
def string_resource(resource)
    mystring="\t" + resource[:type].downcase + '{"' +  resource[:title] + '":'+"\n"
    resource[:parameters].each_pair do |k,v|
    if v.is_a?(Array)
        indent = " " * k.to_s.size

        mystring+="\t     #{k} => [\n"
        v.each do |val|
                mystring+="\t     #{indent}     #{val},\n"
        end
        mystring+="\t     #{indent}    ]\n"
    else
        mystring+="\t     #{k} => #{v}\n"
        end
    end
    mystring+="\t}\n"
end

# Compares two sets of resources and prints the differences
# if the two sets do not include the same resource counts
# this will only print the resources available in both
def compare_resources(old, new, unified)
    puts "Individual Resource differences:"

    old.each do |resource|
        new_resource = new.find{|res| res[:resource_id] == resource[:resource_id]}
        next if new_resource.nil?


        unless new_resource[:parameters] == resource[:parameters]
          if UNIFIED
            #Only print the diff of resources
            puts Diffy::Diff.new(  string_resource(resource),  string_resource(new_resource), :diff => "-U 1000")
          else
            puts "Old Resource:"
            puts string_resource(resource)
            
            puts
            
            puts "New Resource:"
            puts string_resource(new_resource)
          end
        end
    end
end

# Takes arrays of resource titles and shows the differences
def print_resource_diffs(r1, r2)
    diffresources = r1 - r2
    diffresources.each {|resource| puts "\t#{resource}"}
end

from = YAML.load(File.read(FROM))
to = YAML.load(File.read(TO))
unified = UNIFIED 

titles = {}
titles[:to] = extract_titles(to)
titles[:from] = extract_titles(from)

puts "Resource counts:"
puts "\tOld: #{titles[:from].size}"
puts "\tNew: #{titles[:to].size}"

puts

if titles[:from].size > titles[:to].size
    puts "Resources not in new catalog"
    print_resource_diffs(titles[:from], titles[:to])
elsif titles[:to].size > titles[:from].size
    puts "Resources not in old catalog"
    print_resource_diffs(titles[:to], titles[:from])
else
    puts "Catalogs contain the same resources by resource title"
end

puts
puts

compare_resources(from, to, unified)
