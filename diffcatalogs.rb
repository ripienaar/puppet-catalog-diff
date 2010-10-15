#!/usr/bin/env ruby

# A tool to compare catalogs that have been converted to our intermediate
# format using dumplocalconfig.rb
#
# Contact:
# R.I.Pienaar <rip@devco.net> - www.devco.net - @ripienaar

require 'yaml'

if ARGV.size == 2
    FROM = ARGV[0]
    TO = ARGV[1]
else
    puts "Please specify a to and from catelog dump dir"
    exit 1
end

[FROM, TO].each do |r|
    unless File.exist?("#{r}/resources.yaml")
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

# Prints a resource in a way that looks like puppet code
def print_resource(resource)
    puts "\t" + resource[:type].downcase + '{"' +  resource[:title] + '":'
    resource[:parameters].each_pair do |k,v|
        puts "\t     #{k} => #{v}"
    end
    puts "\t}"
end

# Compares two sets of resources and prints the differences
# if the two sets do not include the same resource counts
# this will only print the resources available in both
def compare_resources(old, new)
    puts "Individual Resource differences:"

    old.each do |resource|
        new_resource = new.find{|res| res[:resource_id] == resource[:resource_id]}
        next if new_resource.nil?

        unless new_resource[:parameters] == resource[:parameters]
            puts "Old Resource:"
            print_resource(resource)

            puts

            puts "New Resource:"
            print_resource(new_resource)
        end

    end
end

# Takes arrays of resource titles and shows the differences
def print_resource_diffs(r1, r2)
    diffresources = r1 - r2
    diffresources.each {|resource| puts "\t#{resource}"}
end

from = YAML.load(File.read("#{FROM}/resources.yaml"))
to = YAML.load(File.read("#{TO}/resources.yaml"))

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

compare_resources(from, to)
