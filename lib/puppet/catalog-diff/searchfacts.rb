require 'puppet/network/http_pool'
require 'uri'
require 'json'
module Puppet::CatalogDiff
  class SearchFacts

    def initialize(facts)
      @facts = Hash[facts.split(',').map { |f| f.split('=') }]
    end

    def find_nodes(options = {})
     # Pull all nodes from the yaml cache
     # Then validate they are active nodes against the rest of puppetdb api
     old_server = options[:old_server].split('/')[0]
     old_env = options[:old_server].split('/')[1]
     if options[:use_puppetdb]
       Puppet.debug("Using puppetDB to find active nodes")
       active_nodes = find_nodes_puppetdb(old_env)
     else
       Puppet.debug("Using Fact Reset Interface to find active nodes")
       active_nodes = find_nodes_rest(old_server)
     end
     if options[:filter_local]
       Puppet.debug("Using YAML cache to find active nodes")
       yaml_cache = find_nodes_local()
       active_nodes = yaml_cache
     end
     if active_nodes.empty?
       raise "No active nodes were returned from your fact search"
     end
     active_nodes
    end

    def find_nodes_local
      Puppet[:clientyamldir] = Puppet[:yamldir]
      if Puppet::Node.respond_to? :terminus_class
        Puppet::Node.terminus_class = :yaml
        nodes = Puppet::Node.search("*")
      else
        Puppet::Node.indirection.terminus_class = :yaml
        nodes = Puppet::Node.indirection.search("*")
      end
      unless filtered =  nodes.select {|node|
          @facts.select { |fact, v| node.facts.values[fact] == v }.size == @facts.size
        }.map{ |n| n.name }
        raise "No matching nodes found using yaml terminus"
      end
      filtered
    end


    def find_nodes_rest(server)
        query = @facts.map { |k, v| "facts.#{k}=#{v}" }.join('&')
        # https://github.com/puppetlabs/puppet/blob/3.8.0/api/docs/http_api_index.md#error-responses
        endpoint = "/v2.0/facts_search/search?#{query}"
        server,port = server.split(':')
        port ||= '8140'

        begin
          connection = Puppet::Network::HttpPool.http_instance(server,port)
          facts_object = connection.request_get(endpoint, {"Accept" => 'pson'}).body
        rescue Exception => e
          raise "Error retrieving facts from #{server}: #{e.message}"
        end
        if JSON.load(facts_object).has_key?('issue_kind')
          raise "Not authorized to retrieve facts, auth.conf edits missing?" if facts_object['issue_kind'] == 'FAILED_AUTHORIZATION'
        end
        begin
          filtered = PSON.load(facts_object)
        rescue Exception => e
          raise "Received invalid data from facts endpoint: #{e.message}"
        end
        filtered
    end

    def find_nodes_puppetdb(env)
        require 'puppet/util/puppetdb'
        server_url = Puppet::Util::Puppetdb.config.server_urls[0]
        port = server_url.port
        use_ssl = port != 8080
        connection = Puppet::Network::HttpPool.http_instance(server_url.host,port,use_ssl)
        base_query = ["and", ["=", ["node","active"], true]]
        base_query.concat([["=", "catalog_environment", env]]) if env
        real_facts = @facts.select { |k, v| !v.nil? }
        query = base_query.concat(real_facts.map { |k, v| ["=", ["fact", k], v] })
        classes = Hash[@facts.select { |k, v| v.nil? }].keys
        classes.each do |c|
          capit = c.split('::').map{ |n| n.capitalize }.join('::')
          query = query.concat(
            [["in", "certname",
              ["extract", "certname",
                ["select-resources",
                  ["and",
                    ["=", "type", "Class"],
                    ["=", "title", capit ],
                  ],
                ],
              ],
            ]]
          )
        end
        json_query = URI.escape(query.to_json)
        unless filtered = PSON.load(connection.request_get("/pdb/query/v4/nodes?query=#{json_query}", {"Accept" => 'application/json'}).body)
          raise "Error parsing json output of puppet search"
        end
        names = filtered.map { |node| node['certname'] }
        names
    end                                                                                                                            end
end
