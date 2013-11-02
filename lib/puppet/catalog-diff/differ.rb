require 'yaml'
require 'facter'
require 'pp'
require 'fileutils'
require 'digest/md5'
require 'tempfile'

# helper methods
require File.expand_path(File.join(File.dirname(__FILE__), 'preprocessor.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'comparer.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'formater.rb'))
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

      output = {}
      output['total_in_old'] = titles[:from].size
      output['total_in_new'] = titles[:to].size


      resource_diffs_titles = return_resource_diffs(titles[:to], titles[:from])
      output['only_in_old'] = resource_diffs_titles['titles_only_in_old']
      output['only_in_new'] = resource_diffs_titles['titles_only_in_new']

      resource_diffs = compare_resources(from,to,options)
      output['differences_in_old']  = resource_diffs['old']
      output['differences_in_new']  = resource_diffs['new']
      output['differences_as_diff'] = resource_diffs['string_diffs']
      output['params_in_old']       = resource_diffs['old_params']
      output['params_in_new']       = resource_diffs['new_params']

      additions    = resource_diffs_titles['titles_only_in_new'].size
      subtractions = resource_diffs_titles['titles_only_in_old'].size
      changes_percentage      = 100*(resource_diffs['new_params'].keys.size.to_f / titles[:from].size.to_f)
      additions_percentage    = 100*(additions.abs.to_f / titles[:to].size.to_f)
      subtractions_percentage = 100*(subtractions.abs.to_f / titles[:from].size.to_f)



      output['percentage_added']   = '%.2f' % additions_percentage
      output['percentage_removed'] = '%.2f' % subtractions_percentage
      output['percentage_changed'] = '%.2f' % changes_percentage
      output['resource_changes']   = "#{(!additions.zero?  && "+#{additions}" || 0)} / #{(!subtractions.zero?  && "-#{subtractions}" || 0)}"
      output['total_changes']      = ((changes_percentage + additions_percentage + subtractions_percentage) / 3).round.to_s
      output
    end
  end
end
