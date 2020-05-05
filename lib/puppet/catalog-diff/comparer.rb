require 'puppet/util/diff'
require 'digest'
# Puppet::CatalogDiff
module Puppet::CatalogDiff
  # Comparer providers methods
  # to compare resources
  module Comparer
    # Creates an array of just the resource titles
    # it would be records like file["/foo"]
    def extract_titles(resources)
      titles = []

      resources.each do |resource|
        titles << resource[:resource_id]
      end

      titles
    end

    # Compares two sets of resources and prints the differences
    # if the two sets do not include the same resource counts
    # this will only print the resources available in both
    def compare_resources(old, new, options)
      resource_differences = {}
      differences_in_old = {}
      differences_in_new = {}
      string_differences = {}
      content_differences = {}
      parameters_in_old = {}
      parameters_in_new = {}
      old.each do |resource|
        new_resource = new.find { |res| res[:resource_id] == resource[:resource_id] }
        next if new_resource.nil?

        if options[:ignore_parameters]
          blacklist = options[:ignore_parameters].split(',')
          filter_parameters!(new_resource[:parameters], blacklist)
          filter_parameters!(resource[:parameters], blacklist)
        end

        sort_dependencies!(new_resource[:parameters])
        sort_dependencies!(resource[:parameters])

        next if new_resource[:parameters] == resource[:parameters]

        parameters_in_old[resource[:resource_id]] = \
          Hash[(resource[:parameters].to_a - new_resource[:parameters].to_a)]

        parameters_in_new[resource[:resource_id]] = \
          Hash[(new_resource[:parameters].to_a - resource[:parameters].to_a)]

        if options[:show_resource_diff]
          Puppet.debug("Resource diff: #{resource[:resource_id]}")

          diff_array = str_diff(
            Puppet::CatalogDiff::Formater.new.resource_to_string(resource),
            Puppet::CatalogDiff::Formater.new.resource_to_string(new_resource),
          ).split("\n")
          if diff_array.size >= 3
            string_differences[resource[:resource_id]] = diff_array[3..-1]
          else
            Puppet.debug('Could not automatically detect diff')
            string_differences[resource[:resource_id]] = resource[:parameters].inspect + new_resource[:parameters].inspect
          end

        else
          differences_in_old[resource[:resource_id]] = resource

          differences_in_new[resource[:resource_id]] = new_resource
        end

        cont_diff = str_diff(resource[:parameters][:content], new_resource[:parameters][:content])
        content_differences[resource[:resource_id]] = cont_diff if cont_diff
      end
      resource_differences[:old] = differences_in_old
      resource_differences[:new] = differences_in_new
      resource_differences[:string_diffs] = string_differences
      resource_differences[:content_differences] = content_differences
      resource_differences[:old_params]  = parameters_in_old
      resource_differences[:new_params]  = parameters_in_new
      resource_differences
    end

    # filter parameters
    def filter_parameters!(params, blacklist)
      params.reject! { |p, _k| blacklist.include?(p.to_s) }
    end

    # sort require/before/notify/subscribe before comparison
    def sort_dependencies!(params)
      params.each do |x|
        next unless [:require, :before, :notify, :subscribe].include?(x[0])
        if x[1].class == Array
          x[1].sort!
        end
      end
    end

    # Takes arrays of resource titles and shows the differences
    def return_resource_diffs(r1, r2)
      only_in_old = []
      (r2 - r1).each do |r|
        only_in_old << r.to_s
      end
      only_in_new = []
      (r1 - r2).each do |r|
        only_in_new << r.to_s
      end
      differences = {
        titles_only_in_old: only_in_old,
        titles_only_in_new: only_in_new,
      }
      differences
    end

    def do_str_diff(str1, str2)
      paths = [str1, str2].map do |s|
        tempfile = Tempfile.new('puppet-diffing')
        tempfile.open
        tempfile.print s
        tempfile.close
        tempfile
      end
      diff = Puppet::Util::Diff.diff(paths[0].path, paths[1].path)
      paths.each { |f| f.delete }
      diff
    end

    def str_diff(cont1, cont2)
      return nil unless cont1 && cont2

      if cont1.is_a?(Hash)
        str1 = cont1[:content]
        sum1 = cont1[:checksum]
      else
        str1 = cont1
        sum1 = Digest::MD5.hexdigest(str1)
      end

      if cont2.is_a?(Hash)
        str2 = cont2[:content]
        sum2 = cont2[:checksum]
      else
        str2 = cont2
        sum2 = Digest::MD5.hexdigest(str2)
      end

      return nil unless str1 && str2
      return nil if sum1 == sum2

      @@cached_str_diffs ||= {}
      @@cached_str_diffs["#{sum1}/#{sum2}"] ||= do_str_diff(str1, str2)
    end
  end
end
