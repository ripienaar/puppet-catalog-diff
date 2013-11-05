require 'puppet/face'

Puppet::Face.define(:catalog, '0.0.1') do
  action :pull do
    default
    description "Make a get request"
    arguments "<none>"

    option "--accept FORMAT" do
      summary "What format to accept in the header"

      default_to do
        'json'
      end

      before_action do |action, args, options|
        format = options[:accept].downcase
        unless ['pson', 'json', 'yaml'].include? format
          raise ArgumentError, "--accept format must be json or yaml"
        end
        if format == 'json'
          # This is dumb, but necessary
          format = 'pson'
        end
        options[:accept] = format
      end
  end
  when_invoked do |node_name,options|
      require 'puppet/network/http_pool'
      connection = Puppet::Network::HttpPool.http_instance(Puppet[:server], Puppet[:masterport])
      connection.request_get("/production/catalog/#{node_name}", {"Accept" => options[:accept]}).body
    end
  end
end
