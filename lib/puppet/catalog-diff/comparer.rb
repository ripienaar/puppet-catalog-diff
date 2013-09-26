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

    # creates a string representation of a resource that looks like Puppet code
    def resource_to_string(resource)
      str = ''
      str << "\t" + resource[:type].downcase << '{"' <<  resource[:title].to_s << '":' << "\n"
      resource[:parameters].each_pair do |k,v|
        if v.is_a?(Array)
          indent = " " * k.to_s.size

          str << "\t     #{k} => [" << "\n"
          v.each do |val|
            str << "\t     #{indent}     #{val}," << "\n"
          end
          str << "\t     #{indent}    ]" << "\n"
        else
          if k == :content
            v = v[:checksum]
          end
          str << "\t     #{k} => #{v}" << "\n"
        end
      end
      str << "\t}\n"

    end

    # Prints a resource in a way that looks like puppet code
    def print_resource(resource)
      puts resource_to_string(resource)
    end

    # Compares two sets of resources and prints the differences
    # if the two sets do not include the same resource counts
    # this will only print the resources available in both
    def compare_resources(old, new, options)
      puts "Individual Resource differences:"

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
          if options[:show_resource_diff]
            puts
            puts "Resource diff: #{resource[:resource_id]}"
            puts  str_diff(
                    resource_to_string(resource),
                    resource_to_string(new_resource)
                  ).split("\n")[3..-1].join("\n")
          else
            puts "Old Resource:"
            print_resource(resource)

            puts

            puts "New Resource:"
            print_resource(new_resource)
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
    def print_resource_diffs(r1, r2)
      puts "Only in old:"
      (r2 - r1).each do |r|
        puts "\t#{r}"
      end
      puts "Only in new:"
      (r1 - r2).each do |r|
        puts "\t#{r}"
      end
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
