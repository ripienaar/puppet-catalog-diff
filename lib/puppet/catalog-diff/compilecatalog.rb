module Puppet::CatalogDiff
  class CompileCatalog
    attr_reader :node_name

    def initialize(node_name,save_directory)
      @node_name = node_name
      catalog = render_pson(compile_catalog(node_name))
      save_catalog_to_disk(save_directory,node_name,catalog)
    end

    def lookup_environment(node_name)
      # Compile the catalog with the last environment used according to the yaml terminus
      # The following is a hack as I can't pass :mode => master in the 2.7 series
      Puppet[:clientyamldir] = Puppet[:yamldir]
      Puppet::Util::RunMode[:master]
      unless node = Puppet::Face[:node, '0.0.1'].find(node_name,:terminus => 'yaml' )
        raise "Could not find yaml file for node #{node_name}"
      end
      Puppet.debug("Found environment #{node.environment} for node #{node_name}")
      node.environment
    end

    def compile_catalog(node_name)
      environment = lookup_environment(node_name)
      unless catalog = Puppet::Resource::Catalog.indirection.find(node_name,:environment => environment)
        raise "Could not compile catalog for #{node_name} in environment #{environment}"
      end
      catalog
    end

    def render_pson(catalog)
      unless pson = PSON::pretty_generate(catalog.to_resource, :allow_nan => true, :max_nesting => false)
       raise "Could not render catalog as pson, #{catalog}"
      end
      pson
    end

    def save_catalog_to_disk(save_directory,node_name,catalog)
      File.open("#{save_directory}/#{node_name}.pson","w") do |f|
        f.write(catalog)
      end
    end

  end
end
