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
     if options[:use_puppetdb]
       active_nodes = find_nodes_puppetdb()
     else
       active_nodes = find_nodes_rest(options[:old_server].split('/')[0])
     end
     if active_nodes.empty?
       raise "No active nodes were returned from your fact search"
     end
     if options[:filter_local]
       yaml_cache = find_nodes_local()
       yaml_cache.select { |node| active_nodes.include?(node) }
     else
       active_nodes
     end
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
      unless filtered =  nodes.select {|n|
          @facts.select { |f, v| n[f] == v }.size == @facts.size
        }.map{ |n| n.name }
        raise "No matching nodes found using yaml terminus"
      end
      filtered
    end


    def find_nodes_rest(server)
        query = @facts.map { |k, v| "facts.#{k}=#{v}" }.join('&')
        endpoint = "/v2/facts_search/search?#{query}"

        begin
          connection = Puppet::Network::HttpPool.http_instance(server,'8140')
          facts_object = connection.request_get(endpoint, {"Accept" => 'pson'}).body
        rescue Exception => e
          raise "Error retrieving facts from #{server}: #{e.message}"
        end

        begin
          filtered = PSON.load(facts_object)
        rescue Exception => e
          raise "Received invalid data from facts endpoint: #{e.message}"
        end
        filtered
    end

    def find_nodes_puppetdb()
        connection = Puppet::Network::HttpPool.http_instance(Puppet::Util::Puppetdb.server,'8081')
        base_query = ["and", ["=", ["node","active"], true]]
        query = base_query.concat(@facts.map { |k, v| ["=", ["fact", k], v] })
        json_query = URI.escape(query.to_json)
        unless filtered = PSON.load(connection.request_get("/v2/nodes/?query=#{json_query}", {"Accept" => 'application/json'}).body)
          raise "Error parsing json output of puppet search"
        end
        names = filtered.map { |node| node['name'] }
        names
    end                                                                                                                            end
end
