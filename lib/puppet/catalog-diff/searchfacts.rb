require 'puppet/network/http_pool'
require 'uri'
require 'json'
module Puppet::CatalogDiff
  class SearchFacts

    def initialize(args)
      @args = args
    end

    def find_nodes(options = {})
     # Pull all nodes from the yaml cache
     # Then validate they are active nodes against the rest of puppetdb api
     yaml_cache = find_nodes_local(*@args.split("="))
     if options[:use_puppetdb]
       active_nodes = find_nodes_puppetdb(options[:new_server])
     else
       active_nodes = find_nodes_rest(options[:old_server])
     end
     if active_nodes.empty?
       raise "No active nodes were returned from your fact search"
     end
     found_nodes = yaml_cache.select { |node| active_nodes.include?(node) }
     found_nodes
    end

    def find_nodes_local(fact,value)
      Puppet[:clientyamldir] = Puppet[:yamldir]
      if Puppet::Node.respond_to? :terminus_class
        Puppet::Node.terminus_class = :yaml
        nodes = Puppet::Node.search("*")
      else
        Puppet::Node.indirection.terminus_class = :yaml
        nodes = Puppet::Node.indirection.search("*")
      end
      unless filtered =  nodes.select {|n| n.parameters[fact] == value }.map{ |n| n.name }
        raise "No matching nodes found using yaml terminus"
      end
      filtered
    end


    def find_nodes_rest(server)
        connection = Puppet::Network::HttpPool.http_instance(server,'8140')
        unless filtered = PSON.load(connection.request_get("/v2/facts_search/search?facts.#{@args}", {"Accept" => 'pson'}).body)
          raise "Error parsing pson output of fact search"
        end
        filtered
    end

    def find_nodes_puppetdb(server)
        connection = Puppet::Network::HttpPool.http_instance(server,'8081')
        fact_query = @args.split("=")
        json_query = URI.escape(["=", ["fact", fact_query[0]], fact_query[1]].to_json)
        unless filtered = PSON.load(connection.request_get("/v2/nodes/?query=#{json_query}", {"Accept" => 'application/json'}).body)
          raise "Error parsing json output of puppet search"
        end
        names = filtered.map { |node| node['name'] }
        names
    end                                                                                                                            end
end
