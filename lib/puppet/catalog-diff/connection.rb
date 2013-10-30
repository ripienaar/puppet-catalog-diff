require "net/http"

module Puppet::CatalogDiff
    class Connection
        def initialize(host, port, user, password, ssl=false)
            @user = user
            @password = password
            session = Net::HTTP.new(host, port)
            session.use_ssl = ssl
            session.verify_mode  = OpenSSL::SSL::VERIFY_NONE
            res = session.start do |http|
                @http = http
                yield self
            end
        end

        def send_request(req, data=nil)
            if @user && @password
                req.basic_auth @user, @password
            end

            if data
                req.body = data
            end

            @http.request(req)
        end

        def post(path, data=nil, headers={})
            send_request(Net::HTTP::Post.new(path, headers), data)
        end

        def put(path, data=nil, headers={})
            send_request(Net::HTTP::Put.new(path, headers), data)
        end

        def delete(path, data=nil, headers={})
            send_request(Net::HTTP::Delete.new(path, headers), data)
        end

        def get(path, headers={})
            send_request(Net::HTTP::Get.new(path, headers))
        end
    end
end
