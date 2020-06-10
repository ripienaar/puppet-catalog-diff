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

# Puppet::CatalogDiff
module Puppet::CatalogDiff
  # Differ allows to diff two catalogs
  class Differ
    include Puppet::CatalogDiff::Preprocessor
    include Puppet::CatalogDiff::Comparer

    attr_accessor :from_file, :to_file

    def initialize(from, to)
      @from_file = from
      @to_file = to
    end

    def str_to_catalog(str)
      Puppet::Resource::Catalog.from_data_hash str
    end

    def diff(options = {})
      from = []
      from_meta = {}
      to = []
      to_meta = {}
      { from_file => [from, from_meta], to_file => [to, to_meta] }.each do |r, a|
        v, m = a
        unless File.exist?(r)
          raise "Cannot find resources in #{r}"
        end

        case File.extname(r)
        when '.yaml'
          tmp = YAML.safe_load(File.read(r))
        when '.marshal'
          tmp = Marshal.load(File.read(r))
        when '.pson'
          tmp = PSON.parse(File.read(r))
          tmp = str_to_catalog(tmp) unless tmp.respond_to?(:version)
        when '.json'
          tmp = str_to_catalog(JSON.parse(File.read(r)))
        else
          raise 'Provide catalog with the appropriate file extension, valid extensions are json, pson, yaml and marshal'
        end

        m[:version] = tmp.version
        m[:environment] = tmp.environment

        convert25(tmp, v)
      end

      if options[:exclude_classes]
        [to, from].each do |c|
          c.reject! { |x| x[:type] == 'Class' }
        end
      end

      if options[:exclude_defined_resources]
        [to, from].each do |c|
          c.reject! { |x| x[:type].include?('::') }
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

      resource_diffs_titles = return_resource_diffs(titles[:from], titles[:to])
      output[:only_in_old] = resource_diffs_titles[:titles_only_in_old]
      output[:only_in_new] = resource_diffs_titles[:titles_only_in_new]

      resource_diffs = compare_resources(from, to, options)
      output[:differences_in_old]  = resource_diffs[:old]
      output[:differences_in_new]  = resource_diffs[:new]
      output[:differences_as_diff] = resource_diffs[:string_diffs]
      output[:params_in_old]       = resource_diffs[:old_params]
      output[:params_in_new]       = resource_diffs[:new_params]
      output[:content_differences] = resource_diffs[:content_differences]

      additions    = resource_diffs_titles[:titles_only_in_new].size
      subtractions = resource_diffs_titles[:titles_only_in_old].size
      changes      = resource_diffs[:new_params].keys.size

      changes_percentage      = (titles[:from].size.zero? && 0 || 100 * (resource_diffs[:new_params].keys.size.to_f / titles[:from].size.to_f))
      additions_percentage    = (titles[:to].size.zero?   && 0 || 100 * (additions.to_f / titles[:to].size.to_f))
      subtractions_percentage = (titles[:from].size.zero? && 0 || 100 * (subtractions.to_f / titles[:from].size.to_f))

      output[:catalag_percentage_added]   = '%.2f' % additions_percentage
      output[:catalog_percentage_removed] = '%.2f' % subtractions_percentage
      output[:catalog_percentage_changed] = '%.2f' % changes_percentage
      output[:added_and_removed_resources] = "#{(!additions.zero? && "+#{additions}" || 0)} / #{(!subtractions.zero? && "-#{subtractions}" || 0)}"

      divide_by = (changes_percentage.zero? ? 0 : 1) + (additions_percentage.zero? ? 0 : 1) + (subtractions_percentage.zero? ? 0 : 1)
      output[:node_percentage]       = (divide_by == 0 && 0 || additions_percentage == 100 && 100 || (changes_percentage + additions_percentage + subtractions_percentage) / divide_by).to_f
      output[:node_differences]      = (additions.abs.to_i + subtractions.abs.to_i + changes.abs.to_i)
      output
    end
  end
end
