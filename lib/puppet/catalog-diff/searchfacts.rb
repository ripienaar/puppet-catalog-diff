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
      get_matching_hosts(/.*/)
    end

    def get_matching_hosts(pattern)
        Puppet::CatalogDiff::Connection.new(@host, @port, @user, @pass, true) do |rest|
            path = "/v2/facts_search/search?facts.#{@args}"
            all_hosts = YAML::load(rest.get(path,{"Accept" => "yaml"}).body)
            return all_hosts.find_all{|host| Regexp.new(pattern) =~ host}
        end
    end
  end
end
