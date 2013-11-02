require 'puppet/util/diff'
module Puppet::CatalogDiff
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
      parameters_in_old = {}
      parameters_in_new = {}
      old.each do |resource|
        new_resource = new.find{|res| res[:resource_id] == resource[:resource_id]}
        next if new_resource.nil?

        # 0.24.x would set eg. on exec the command property to the same as name
        # even when they were the same, 25 onward doesnt so get rid of these.
        #
        # there are no doubt many more
        #resource[:parameters].delete(:name) unless new_resource[:parameters].include?(:name)
        #resource[:parameters].delete(:command) unless new_resource[:parameters].include?(:command)
        #resource[:parameters].delete(:path) unless new_resource[:parameters].include?(:path)

        sort_dependencies!(new_resource[:parameters])
        sort_dependencies!(resource[:parameters])

        unless new_resource[:parameters] == resource[:parameters]
          parameters_in_old[resource[:resource_id]] = \
          Hash[*(resource[:parameters].to_a - new_resource[:parameters].to_a ).flatten]

          parameters_in_new[resource[:resource_id]] = \
          Hash[*(new_resource[:parameters].to_a - resource[:parameters].to_a ).flatten]

          if options[:show_resource_diff]
            Puppet.debug("Resource diff: #{resource[:resource_id]}")

            diff_array = str_diff(
                           Puppet::CatalogDiff::Formater.new().resource_to_string(resource),
                           Puppet::CatalogDiff::Formater.new().resource_to_string(new_resource)
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

          if options[:content_diff] && resource[:parameters][:content] && new_resource[:parameters][:content] && resource[:parameters][:content][:checksum] != new_resource[:parameters][:content][:checksum]
            puts
            puts "Content diff:"

            puts str_diff(resource[:parameters][:content][:content], new_resource[:parameters][:content][:content])
            puts "-" * 80
            puts
          end
        end

      end
      resource_differences['old'] = differences_in_old
      resource_differences['new'] = differences_in_new
      resource_differences['string_diffs'] = string_differences
      resource_differences['old_params']  = parameters_in_old
      resource_differences['new_params']  = parameters_in_new
      resource_differences
    end

    # sort require/before/notify/subscribe before comparison
    def sort_dependencies!(params)
      params.each do |x|
        if [:require, :before, :notify, :subscribe].include?(x[0])
          if x[1].class == Array
            x[1].sort!
          end
        end
      end
    end

    # Takes arrays of resource titles and shows the differences
    def return_resource_diffs(r1, r2)
      only_in_old = []
      (r2 - r1).each do |r|
        only_in_old << "#{r}"
      end
      only_in_new = []
      (r1 - r2).each do |r|
        only_in_new << "#{r}"
      end
      differences = {
        'titles_only_in_old' => only_in_old,
        'titles_only_in_new' => only_in_new,
      }
      differences
    end

    def str_diff(str1, str2)
      paths = [str1,str2].collect do |s|
        tempfile = Tempfile.new("puppet-diffing")
        tempfile.open
        tempfile.print s
        tempfile.close
        tempfile
      end
      diff = Puppet::Util::Diff.diff(paths[0].path, paths[1].path)
      paths.each { |f| f.delete }
      diff
    end
  end
end
