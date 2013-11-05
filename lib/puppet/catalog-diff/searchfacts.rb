require 'puppet/network/http_pool'
require File.expand_path(File.join(File.dirname(__FILE__), 'connection.rb'))
module Puppet::CatalogDiff
  class SearchFacts

    def initialize(args)
      @args = args
      @host = 'localhost'
      @port = '8140'
    end

    def find_nodes(options = {})
      get_matching_hosts()
    end

    def get_matching_hosts()
        connection = Puppet::Network::HttpPool.http_instance(Facter.value("fqdn"),'8140')
        unless all_hosts = YAML::load(connection.request_get("/v2/facts_search/search?facts.#{@args}", {"Accept" => 'yaml'}).body)
          raise "Error parsing yaml output of fact search"
        end
        all_hosts
    end
  end
end
