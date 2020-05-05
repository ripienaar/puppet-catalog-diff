# Puppet::CatalogDiff
module Puppet::CatalogDiff
  # Puppet::CatalogDiff::Preprocessor
  # provides methods to convert catalogs to
  # the catalog-diff intermediate format
  module Preprocessor
    # capitalize a resource from ["class", "foo::bar"] to Class[Foo::Bar]
    #
    # Dear Puppet 0.24.  Die.
    def capitalizeresource(resource)
      res = ''

      if resource[0] =~ %r{class}i
        res << 'Class['
        res << resource[1].split(%r{::}).map { |r| r.capitalize }.join('::')
        res << ']'
      else
        res << resource[0].capitalize
        res << '[' << resource[1] << ']'
      end

      res
    end

    # Converts Puppet 0.25 and 2.6.x catalogs to our intermediate format
    def convert25(resource, collector)
      if resource.is_a?(Puppet::Resource::Catalog)
        resource.edges.each do |b|
          convert25(b, collector)
        end
      elsif resource.is_a?(Puppet::Relationship) && resource.target.is_a?(Puppet::Resource) && resource.target.title
        target = resource.target

        resource = { type: target.type,
                     title: target.title,
                     parameters: {} }

        target.each do |param, value|
          resource[:parameters][param] = value
        end

        if resource[:parameters].include?(:content) && resource[:parameters][:content].is_a?(String)
          resource[:parameters][:content] = { checksum: Digest::MD5.hexdigest(resource[:parameters][:content]), content: resource[:parameters][:content] }
        end

        resource[:resource_id] = "#{target.type.downcase}[#{target.title}]"
        collector << resource
      end
    end

    # Converts PuppetDB catalogs to our intermediate format
    def convert_pdb(catalog)
      catalog = catalog[0]
      # Fix "data" level in PuppetDB catalog
      catalog['resources'] = catalog['resources']['data']
      # Fix edges
      new_edges = []
      catalog['edges']['data'].each do |edge|
        new_edges << {
          'source' => "#{edge['source_type']}[#{edge['source_title']}]",
          'target' => "#{edge['target_type']}[#{edge['target_title']}]",
        }
      end
      catalog['edges'] = new_edges
      catalog
    end
  end
end
