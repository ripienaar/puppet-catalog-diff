# A tool to compare catalogs that have been generated via puppet master --compile
#
# Contact:
# R.I.Pienaar <rip@devco.net> - www.devco.net - @ripienaar

require 'yaml'
require 'facter'
require 'pp'
require 'fileutils'
require 'digest/md5'

# helper methods
require 'puppet/catalog-diff/preprocessor'
require 'puppet/catalog-diff/comparer'


module Puppet::CatalogDiff
class Differ

  include Puppet::CatalogDiff::Preprocessor
  include Puppet::CatalogDiff::Comparer

  attr_accessor :from_file, :to_file

  def initialize(from, to)
    @from_file = from
    @to_file = to

    check_version
  end

  def check_version
    if Puppet.version =~ /^([0-9]+[.][0-9]+)[.][0-9]+/
        @version = $1

        unless ["0.24", "0.25", "2.6", "2.7", "3.0"].include?(@version)
            raise "Don't know how to compare catalogs for version #{Puppet.version}. Only 0.24, 0.25, 2.6, 2.7 and 3.0 are supported"
        end
    else
        raise "Could not figure out version from #{Puppet.version}"
    end
  end

  def diff(options = {})
    from = []
    to   = []
    { from_file => from, to_file => to}.each do |r,v|
        unless File.exist?(r)
            raise "Cannot find resources in #{r}"
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

    compare_resources(from, to, options)
    nil
  end
end
end
