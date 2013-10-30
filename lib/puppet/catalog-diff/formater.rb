module Puppet::CatalogDiff
  class Formater

    def initialize()
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

  end
end
