require 'puppet/util/terminal'
module Puppet::CatalogDiff
  class Formater
    def initialize; end

    def format_simple(v, indent = '', do_indent = false, comma = '')
      str = ''
      str << indent if do_indent
      v = "\"#{v}\"" unless [Integer, TrueClass, FalseClass].include?(v.class)
      str << v.to_s << comma << "\n"
    end

    def format_array(v, indent = '', do_indent = false, comma = '')
      str = ''
      str << indent if do_indent
      str << '[' << "\n"
      v.each do |val|
        str << format_value(val, "#{indent}     ", true, ',')
      end
      str << "\t     #{indent}    ]" << "\n" << comma
    end

    def format_hash(v, indent = '', do_indent = false, comma = '')
      str = ''
      str << indent if do_indent
      str << '{' << "\n"
      keys = Hash[(v.sort_by { |key, _val| key })]
      keys.each_pair do |key, val|
        str << "\t     #{indent}     #{key} => "
        str << format_value(val, "#{indent}     ", true, ',', key)
      end
      str << "\t     #{indent}    }" << "\n" << comma
    end

    def format_value(v, indent = '', do_indent = false, comma = '', k = nil)
      if v.is_a?(Array)
        format_array(v, indent, do_indent, comma)
      elsif v.is_a?(Hash)
        format_hash(v, indent, do_indent, comma)
      else
        v = v[:checksum] if k == :content && v.is_a?(Hash)
        format_simple(v, indent, do_indent, comma)
      end
    end

    # creates a string representation of a resource that looks like Puppet code
    def resource_to_string(resource)
      str = ''
      str << "\t" + resource[:type].downcase << '{"' << resource[:title].to_s << '":' << "\n"
      params = Hash[(resource[:parameters].sort_by { |k, _v| k })]
      params.each_pair do |k, v|
        str << "\t     #{k} => "
        indent = ' ' * k.to_s.size
        str << format_value(v, indent, false, '', k)
      end
      str << "\t}\n"
      str
    end

    def node_summary_header(node, summary, key)
      header_spacing = ' ' * (79 - (node.length + summary[key].to_s.length))
      "\n#{'-' * 80}\n\033[1m#{node}#{header_spacing}#{summary[key]}% \033[0m\n#{'-' * 80}\n"
    end

    def catalog_summary_header(header, number)
      header_spacing = ' ' * (79 - ("Total #{header}".length + number.to_s.length))
      "\n#{'-' * 80}\n\033[1mTotal #{header.to_s.tr('_', ' ').capitalize}#{header_spacing}#{number} \033[0m\n#{'-' * 80}\n"
    end

    def resource_reference(header, resource_id, resource)
      dsl = resource_to_string(resource)
      "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n\n#{dsl}"
    end

    def string_diff(header, resource_id, resource)
      list = "\t#{resource_id.capitalize}\n" + resource.map { |k|
        k.to_s
      }.join("\n")
      "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n#{list}"
    end

    def params_diff(header, resource_id, resource)
      if resource.is_a?(String)
        "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n#{resource}"
      else
        params = resource.map { |k, v|
          "\t#{k} = #{v}"
        }.join("\n")
        "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n\t#{resource_id.capitalize}:\n#{params}"
      end
    end

    def list(header, value)
      list = value.map { |k|
        "\t#{k}"
      }.join("\n")
      "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n#{list}"
    end

    def list_hash(header, value, mark = '%')
      number = 0
      list = value.map { |hash|
        number += 1
        hash.map do |key, val|
          header_spacing = ' ' * (79 - ("#{number}. #{key}".length + ((mark == '%' && '%.2f' % val || val)).to_s.to_s.length))
          "#{number}. #{key}#{header_spacing}#{(mark == '%' && '%.2f' % val || val)}#{mark}"
        end
      }.join("\n")
      "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n#{list}"
    end

    def list_error_hash(header, value)
      number = 0
      list = value.map { |hash|
        number += 1
        hash.map do |key, val|
          "\033[1m#{number}. #{val}\033[0m\n\t#{key}\n"
        end
      }.join("\n")
      "\n#{'-' * 80}\n\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n#{'-' * 80}\n#{list}"
    end

    def list_file_hash(header, value)
      number = 0
      list = value.map { |hash|
        number += 1
        hash.map do |key, val|
          header_spacing = ' ' * (79 - ('    Affected nodes'.length + val.to_s.length))
          "#{number}. #{key}\n    Affected nodes:#{header_spacing}#{val}"
        end
      }.join("\n")
      "\n#{'-' * 80}\n\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\n#{'-' * 80}\n#{list}"
    end

    def key_pair(header, value)
      "\033[1m#{header.to_s.tr('_', ' ').capitalize}\033[0m:\t#{value}"
    end

    def render_pull(output)
      output.map { |key, value|
        if value.is_a?(Array) && key == :failed_to_compile_files
          list_file_hash('Failed to compiled sorted by file', value)
        elsif value.is_a?(Array) && key == :example_compile_errors
          list_error_hash(key, value)
        end
      }.join("\n") + node_summary_header("#{output[:failed_nodes_total]} out of #{output[:total_nodes]} nodes failed to compile. failure rate:", output, :total_percentage).to_s
    end
  end
end
