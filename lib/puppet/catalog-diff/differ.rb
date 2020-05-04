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
      from_meta = {}
      to   = []
      to_meta = {}
      { from_file => [ from, from_meta ], to_file => [ to, to_meta ]}.each do |r,a|
        v, m = a
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
          unless tmp.respond_to? :version
            if Puppet::Resource::Catalog.respond_to? :from_data_hash
              tmp = Puppet::Resource::Catalog.from_data_hash tmp
            else
              # The method was renamed in 3.5.0
              tmp = Puppet::Resource::Catalog.from_pson tmp
            end
          end
        when '.json'
          if Puppet::Resource::Catalog.respond_to? :from_data_hash
            tmp = Puppet::Resource::Catalog.from_data_hash JSON.load(File.read(r))
          else
            # The method was renamed in 3.5.0
            tmp = Puppet::Resource::Catalog.from_pson JSON.load(File.read(r))
          end
        else
          raise "Provide catalog with the appropriate file extension, valid extensions are pson, yaml and marshal"
        end

        m[:version] = tmp.version
        m[:environment] = tmp.environment

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


      Puppet.debug("Processing: #{from_file}")
      titles = {}
      titles[:to] = extract_titles(to)
      titles[:from] = extract_titles(from)

      output = {}
      output[:old_version] = from_meta[:version]
      output[:new_version] = to_meta[:version]

      output[:old_environment] = from_meta[:environment]
      output[:new_environment] = to_meta[:environment]

      output[:total_resources_in_old] = titles[:from].size
      output[:total_resources_in_new] = titles[:to].size


      resource_diffs_titles = return_resource_diffs(titles[:to], titles[:from])
      output[:only_in_old] = resource_diffs_titles[:titles_only_in_old]
      output[:only_in_new] = resource_diffs_titles[:titles_only_in_new]

      resource_diffs = compare_resources(from,to,options)
      output[:differences_in_old]  = resource_diffs[:old]
      output[:differences_in_new]  = resource_diffs[:new]
      output[:differences_as_diff] = resource_diffs[:string_diffs]
      output[:params_in_old]       = resource_diffs[:old_params]
      output[:params_in_new]       = resource_diffs[:new_params]
      output[:content_differences] = resource_diffs[:content_differences]

      additions    = resource_diffs_titles[:titles_only_in_new].size
      subtractions = resource_diffs_titles[:titles_only_in_old].size
      changes      = resource_diffs[:new_params].keys.size

      changes_percentage      = (titles[:from].size.zero? && 0 || 100*(resource_diffs[:new_params].keys.size.to_f / titles[:from].size.to_f))
      additions_percentage    = (titles[:to].size.zero?   && 0 || 100*(additions.to_f / titles[:to].size.to_f))
      subtractions_percentage = (titles[:from].size.zero? && 0 || 100*(subtractions.to_f / titles[:from].size.to_f))


      output[:catalag_percentage_added]   = '%.2f' % additions_percentage
      output[:catalog_percentage_removed] = '%.2f' % subtractions_percentage
      output[:catalog_percentage_changed] = '%.2f' % changes_percentage
      output[:added_and_removed_resources]   = "#{(!additions.zero?  && "+#{additions}" || 0)} / #{(!subtractions.zero?  && "-#{subtractions}" || 0)}"

      divide_by = (changes_percentage.zero? ? 0 : 1) + (additions_percentage.zero? ? 0 : 1) + (subtractions_percentage.zero? ? 0 : 1)
      output[:node_percentage]       = (divide_by == 0 && 0 || additions_percentage == 100 && 100 || (changes_percentage + additions_percentage + subtractions_percentage) / divide_by ).to_f
      output[:node_differences]      = (additions.abs.to_i + subtractions.abs.to_i + changes.abs.to_i )
      output
    end
  end
end
