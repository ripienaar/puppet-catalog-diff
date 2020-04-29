require 'puppet/network/http_pool'
module Puppet::CatalogDiff
  class CompileCatalog
    attr_reader :node_name

    def initialize(node_name,save_directory,server,certless)
      @node_name = node_name
      catalog = compile_catalog(node_name,server,certless)
      begin
        p = PSON.parse(catalog)
        if p.has_key?('issue_kind')
          raise p['message']
        end
        if certless
          catalog = render_pson(p['catalog'])
        end
        save_catalog_to_disk(save_directory,node_name,catalog,'pson')
      rescue Exception => e
        Puppet.err("Server returned invalid catalog for #{node_name}")
        save_catalog_to_disk(save_directory,node_name,catalog,'error')
        if catalog =~ /.document_type.:.Catalog./
          raise e.message
        else
          raise catalog
        end
      end
    end

    def lookup_environment(node_name)
      # Compile the catalog with the last environment used according to the yaml terminus
      # The following is a hack as I can't pass :mode => master in the 2.7 series
      unless node = Puppet::Face[:node, '0.0.1'].find(node_name,:terminus => 'yaml' )
        raise "Error retrieving node object from yaml terminus #{node_name}"
      end
      Puppet.debug("Found environment #{node.environment} for node #{node_name}")
      if node.parameters['clientcert'] != node_name
        raise "The node retrieved from yaml terminus is a mismatch node returned was (#{node.parameters['clientcert']})"
      end
      node.environment
    end

    def compile_catalog(node_name,server,certless)
      server,environment = server.split('/')
      environment ||= lookup_environment(node_name)
      server,port = server.split(':')
      port ||= '8140'
      headers = {
        'Accept' => 'pson',
      }

      if certless
        endpoint = '/puppet/v4/catalog'
        headers['Content-Type'] = 'text/json'
        body = {
          certname: node_name,
          environment: environment,
          persistence: {
            facts: false,
            catalog: false,
          },
        }
      else
        endpoint = "/puppet/v3/catalog/#{node_name}?environment=#{environment}"
      end

      Puppet.debug("Connecting to server: #{server}")
      begin
        connection = Puppet::Network::HttpPool.http_instance(server,port)

        if certless
          catalog = connection.request_post(endpoint, body.to_json, headers).body
        else
          catalog = connection.request_get(endpoint, headers).body
        end
      rescue Exception => e
        raise "Failed to retrieve catalog for #{node_name} from #{server} in environment #{environment}: #{e.message}"
      end
      catalog
    end

    def render_pson(catalog)
      unless pson = PSON::pretty_generate(catalog, :allow_nan => true, :max_nesting => false)
       raise "Could not render catalog as pson, #{catalog}"
      end
      pson
    end

    def save_catalog_to_disk(save_directory,node_name,catalog,extention)
      File.open("#{save_directory}/#{node_name}.#{extention}","w") do |f|
        f.write(catalog)
      end
    rescue Exception => e
      raise "Failed to save catalog for #{node_name} in #{save_directory}: #{e.message}"
    end

  end
end
