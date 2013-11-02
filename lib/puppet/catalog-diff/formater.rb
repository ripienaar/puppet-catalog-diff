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

    def node_summary_header(node,summary)
      header_spacing = ' ' * (79 - (node.length + summary['total_changes'].length)).to_i
      "#{"-" * 80}\n\033[1m#{node}#{header_spacing}#{summary['total_changes']}% \033[0m\n#{"-" * 80}\n"
    end

    def resource_reference(header,resource_id,resource)
      dsl = format.resource_to_string(resource)
      "\033[1m#{header.gsub("_"," ").capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n\n#{dsl}"
    end

    def string_diff(header,resource_id,resource)
      list = "\t#{resource_id}\n" + resource.collect do |k|
        "#{k}"
      end.join("\n")
      "\033[1m#{header.gsub("_"," ").capitalize}\033[0m:\n#{list}"
    end

    def params_diff(header,resource_id,resource)
      params = resource.collect do |k,v|
        "#{k} = #{v}"
      end.join("\n")
      "\033[1m#{header.gsub("_"," ").capitalize}\033[0m:\n\t#{resource_id}:\n\t#{params}"
    end
    def list(header,value)
      list = value.collect do |k|
        "\t#{k}"
      end.join("\n")
      "\033[1m#{header.gsub("_"," ").capitalize}\033[0m:\n#{list}"
    end
    def key_pair(header,value)
      "\033[1m#{header.gsub("_"," ").capitalize}\033[0m:\t#{value}"
    end
  end
end
