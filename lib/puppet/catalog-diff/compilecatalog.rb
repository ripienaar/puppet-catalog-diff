require 'puppet/network/http_pool'
module Puppet::CatalogDiff
  class CompileCatalog
    attr_reader :node_name

    def initialize(node_name,save_directory)
      @node_name = node_name
      catalog = compile_catalog(node_name)
      begin
        PSON.load(catalog)
        save_catalog_to_disk(save_directory,node_name,catalog,'pson')
      rescue
        Puppet.err("Error compiling catalog #{catalog}")
        save_catalog_to_disk(save_directory,node_name,catalog,'error')
      end
    end

    def lookup_environment(node_name)
      # Compile the catalog with the last environment used according to the yaml terminus
      # The following is a hack as I can't pass :mode => master in the 2.7 series
      Puppet[:clientyamldir] = Puppet[:yamldir]
      unless node = Puppet::Face[:node, '0.0.1'].find(node_name,:terminus => 'yaml' )
        raise "Error retrieving node object from yaml terminus #{node_name}"
      end
      Puppet.debug("Found environment #{node.environment} for node #{node_name}")
      if node.parameters['clientcert'] != node_name
        raise "The node retrieved from yaml terminus is a mismatch (missing yaml fact file?)"
      end
      node.environment
    end

    def compile_catalog(node_name)
      environment = lookup_environment(node_name)
      connection = Puppet::Network::HttpPool.http_instance(Facter.value("fqdn"),'8140')
      unless catalog = connection.request_get("/#{environment}/catalog/#{node_name}", {"Accept" => 'pson'}).body
        #unless catalog = Puppet::Resource::Catalog.indirection.find(node_name,:environment => environment)
        raise "Could not compile catalog for #{node_name} in environment #{environment}"
      end
      catalog
    end

    def render_pson(catalog)
      unless pson = PSON::pretty_generate(catalog, :allow_nan => true, :max_nesting => false)
        #unless pson = PSON::pretty_generate(catalog.to_resource, :allow_nan => true, :max_nesting => false)
       raise "Could not render catalog as pson, #{catalog}"
      end
      pson
    end

    def save_catalog_to_disk(save_directory,node_name,catalog,extention)
      File.open("#{save_directory}/#{node_name}.#{extention}","w") do |f|
        f.write(catalog)
      end
    end

  end
end
