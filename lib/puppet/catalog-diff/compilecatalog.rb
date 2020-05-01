require 'puppet/network/http_pool'
module Puppet::CatalogDiff
  class CompileCatalog
    attr_reader :node_name

    def initialize(node_name,save_directory,server,certless,catalog_from_puppetdb)
      @node_name = node_name
      if catalog_from_puppetdb
        catalog = get_catalog_from_puppetdb(node_name,server)
      else
        catalog = compile_catalog(node_name,server,certless)
      end
      catalog = render_pson(catalog)
      begin
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

    def get_catalog_from_puppetdb(node_name,server)
      Puppet.debug("Getting PuppetDB catalog for #{node_name}")
      require 'puppet/util/puppetdb'
      server_url = Puppet::Util::Puppetdb.config.server_urls[0]
      port = server_url.port
      use_ssl = port != 8080
      connection = Puppet::Network::HttpPool.http_instance(server_url.host,port,use_ssl)
      query = ["and", ["=", "certname","#{node_name}"]]
      server,environment = server.split('/')
      environment ||= lookup_environment(node_name)
      query.concat([["=", "environment", environment]])
      json_query = URI.escape(query.to_json)
      ret = connection.request_get("/pdb/query/v4/catalogs?query=#{json_query}", {"Accept" => 'application/json'}).body
      begin
        catalog = PSON.parse(ret)
      rescue PSON::ParserError => e
        raise "Error parsing json output of puppetdb catalog query for #{node_name}: #{e.message}\ncontent: #{ret}"
      end
      catalog = catalog[0]
      # Fix "data" level in PuppetDB catalog
      catalog['resources'] = catalog['resources']['data']
      # Fix edges
      new_edges = []
      catalog['edges']['data'].each do |e|
        new_edges << {
          'source' => "#{e['source_type']}[#{e['source_title']}]",
          'target' => "#{e['target_type']}[#{e['target_title']}]",
        }
      end
      catalog['edges'] = new_edges
      catalog
    end

    def compile_catalog(node_name,server,certless)
      Puppet.debug("Compiling catalog for #{node_name}")
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

      Puppet.debug("Connecting to server: #{server}#{endpoint}")
      begin
        connection = Puppet::Network::HttpPool.http_instance(server,port)

        if certless
          ret = connection.request_post(endpoint, body.to_json, headers).body
        else
          ret = connection.request_get(endpoint, headers).body
        end
      rescue Exception => e
        raise "Failed to retrieve catalog for #{node_name} from #{server} in environment #{environment}: #{e.message}"
      end

      begin
        catalog = PSON.parse(ret)
      rescue PSON::ParserError => e
        raise "Error parsing json output of puppet catalog query for #{node_name}: #{e.message}. Content: #{ret}"
      end
      if catalog.has_key?('issue_kind')
        raise catalog['message']
      end
      if certless
        catalog = catalog['catalog']
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
