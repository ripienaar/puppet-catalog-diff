require 'yaml'
require 'facter'
require 'pp'
require 'fileutils'
require 'digest/md5'
require 'tempfile'

# helper methods
require File.expand_path(File.join(File.dirname(__FILE__), 'preprocessor.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'comparer.rb'))

module Puppet::CatalogDiff
  class Differ

    include Puppet::CatalogDiff::Preprocessor
    include Puppet::CatalogDiff::Comparer

    attr_accessor :from_file, :to_file

    def initialize(from, to)
      @from_file = from
      @to_file = to
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
        when '.json'
          tmp = PSON.load(File.read(r))
	else 
	  raise "Provide catalog with the approprtiate file extension, valid extensions are pson, yaml and marshal"
        end

        if @version == "0.24"
          convert24(tmp, v)
        else
          convert25(tmp, v)
        end
      end

      if options[:exclude_classes]
        [to, from].each do |x|
          x.reject! {|x| x[:type] == 'Class' }
        end
      end 

      titles = {}
      titles[:to] = extract_titles(to)
      titles[:from] = extract_titles(from)
      summary = {}
      resources = {}
      resources['old'] = titles[:from].size
      resources['new'] = titles[:to].size

      list = return_resource_diffs(titles[:to], titles[:from])
      resources['list'] = list
      summary = {
        'resources' => resources
      }
      output  = {
        'summary'  => summary,
      }
      if options[:show_resource_diff]
        compare_resources(from, to, options)
      end
      output
    end
  end
end
