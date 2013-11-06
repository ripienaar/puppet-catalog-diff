require 'puppet/util/terminal'

module Puppet::CatalogDiff
  class Formater

    def initialize()
    end

    # creates a string representation of a resource that looks like Puppet code
    def resource_to_string(resource)
      str = ''
      str << "\t" + resource[:type].downcase << '{"' <<  resource[:title].to_s << '":' << "\n"
      params = Hash[(resource[:parameters].sort_by {|k, v| k})]
      params.each_pair do |k,v|
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

    def node_summary_header(node,summary,key)
      header_spacing = ' ' * (79 - (node.length + summary[key].to_s.length))
      "\n#{"-" * 80}\n\033[1m#{node}#{header_spacing}#{summary[key]}% \033[0m\n#{"-" * 80}\n"
    end

    def catalog_summary_header(header,number)
      header_spacing = ' ' * (79 - ("Total #{header}".length + number.to_s.length))
      "\n#{"-" * 80}\n\033[1mTotal #{header.to_s.gsub("_"," ").capitalize}#{header_spacing}#{number} \033[0m\n#{"-" * 80}\n"
    end

    def resource_reference(header,resource_id,resource)
      dsl = self.resource_to_string(resource)
      "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n\n#{dsl}"
    end

    def string_diff(header,resource_id,resource)
      list = "\t#{resource_id.capitalize}\n" + resource.collect do |k|
        "#{k}"
      end.join("\n")
      "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n#{list}"
    end

    def params_diff(header,resource_id,resource)
      unless resource.is_a?(String)
        params = resource.collect do |k,v|
          "\t#{k} = #{v}"
        end.join("\n")
        "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n#{params}"
      else
        "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n#{resource}"
      end
    end
    def list(header,value)
      list = value.collect do |k|
        "\t#{k}"
      end.join("\n")
      "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n#{list}"
    end
    def list_hash(header,value)
      number = 0
      list = value.collect do |hash|
        number += 1
        hash.collect do |key,value|
          header_spacing = ' ' * (79 - ("#{number}. #{key}".length + "#{'%.2f' % value}".to_s.length))
          "#{number}. #{key}#{header_spacing}#{'%.2f' % value}%"
        end
      end.join("\n")
      "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n#{list}"
    end

    def list_file_hash(header,value)
      number = 0
      list = value.collect do |hash|
        number += 1
        hash.collect do |key,value|
          header_spacing = ' ' * (79 - ("    Affected nodes".length + value.to_s.length))
          "#{number}. #{key}\n    Affected nodes:#{header_spacing}#{value}"
        end
      end.join("\n")
      "\n#{"-" * 80}\n\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\n#{"-" * 80}\n#{list}"
    end
    def key_pair(header,value)
      "\033[1m#{header.to_s.gsub("_"," ").capitalize}\033[0m:\t#{value}"
    end
  end
end
