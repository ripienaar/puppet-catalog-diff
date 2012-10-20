# A tool to compare catalogs that have been generated via puppet master --compile
#
# Contact:
# R.I.Pienaar <rip@devco.net> - www.devco.net - @ripienaar

################# start methods to compare intermediate format #################

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

  # Prints a resource in a way that looks like puppet code
  def print_resource(resource)
      puts "\t" + resource[:type].downcase + '{"' +  resource[:title] + '":'
      resource[:parameters].each_pair do |k,v|
      if v.is_a?(Array)
          indent = " " * k.to_s.size

          puts "\t     #{k} => ["
          v.each do |val|
                  puts "\t     #{indent}     #{val},"
          end
          puts "\t     #{indent}    ]"
      else
          puts "\t     #{k} => #{v}"
          end
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

      # 0.24.x would set eg. on exec the command property to the same as name
      # even when they were the same, 25 onward doesnt so get rid of these.
      #
      # there are no doubt many more
      #resource[:parameters].delete(:name) unless new_resource[:parameters].include?(:name)
      #resource[:parameters].delete(:command) unless new_resource[:parameters].include?(:command)
      #resource[:parameters].delete(:path) unless new_resource[:parameters].include?(:path)

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
      puts "Only in old:"
      (r2 - r1).each do |r|
        puts "\t#{r}"
      end
      puts "Only in new:"
      (r1 - r2).each do |r|
        puts "\t#{r}"
      end
  end
end
end

################# end methods to compare intermediate format ###################
