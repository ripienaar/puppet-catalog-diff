require 'puppet/network/http_pool'
module Puppet::CatalogDiff
  class SearchFacts

    def initialize(args)
      @args = args
    end

    def find_nodes(options = {})
      find_nodes_local(*@args.split("="))
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


    def find_notes_remote(server)
        connection = Puppet::Network::HttpPool.http_instance(server,'8140')
        unless filtered = YAML::load(connection.request_get("/v2/facts_search/search?facts.#{@args}", {"Accept" => 'yaml'}).body)
          raise "Error parsing yaml output of fact search"
        end
        filtered
    end
  end
end
