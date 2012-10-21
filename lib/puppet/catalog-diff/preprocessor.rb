# A tool to compare catalogs that have been generated via puppet master --compile
#
# Contact:
# R.I.Pienaar <rip@devco.net> - www.devco.net - @ripienaar

################# start methods to generate intermediate format ################

module Puppet::CatalogDiff
  module Preprocessor

    # capitalize a resource from ["class", "foo::bar"] to Class[Foo::Bar]
    #
    # Dear Puppet 0.24.  Die.
    def capitalizeresource(resource)
      res = ""

      if resource[0] =~ /class/i
        res << "Class["
        res << resource[1].split(/::/).map{|r| r.capitalize}.join("::")
        res << "]"
      else
        res << resource[0].capitalize
        res << "[" << resource[1] << "]"
      end

      res
    end

    def convert24_resource_array(resources)
      if resources[0].is_a?(Array)
        res = []
        resources.each do |req|
          res << capitalizeresource(req)
        end
      else
        res = capitalizeresource(resources)
      end

      res
    end

    # Converts Puppet 0.24 and possibly earlier catalogs
    # to our intermediate format
    def convert24(bucket, collector)
      if bucket.class == Puppet::TransBucket
        bucket.each do |b|
          convert24(b, collector)
        end
      elsif bucket.class == Puppet::TransObject
        manifestfile = bucket.file.gsub("/etc/puppet/manifests/", "")

        resource = {:type => bucket.type,
          :title => bucket.name,
          :parameters => {}}

        bucket.each do |param, value|
          resource[:parameters][param.to_sym] = value
        end


        # remove some dupe properties that 24 tends to put in
        # that 25 onward doesnt.  This isnt great since some people
        # do specify both even when they're the same, for those it
        # will raise false positives but I guess the bulk use case
        # is being catered for here
        [:name, :command, :path].each do |property|
          if resource[:parameters].include?(property)
            if resource[:title] == resource[:parameters][property]
              resource[:parameters].delete(property)
            end
          end
        end

        # Fix up some other weird resources like File in 24 that used
        # name but now use path
        if resource[:type] == "file" && resource[:parameters].include?(:name)
          resource[:parameters][:path] = resource[:parameters][:name]
          resource[:parameters].delete(:name)
        end

        [:subscribe, :require, :notify, :before].each do |property|
          if resource[:parameters].include?(property)
            resource[:parameters][property] = convert24_resource_array(resource[:parameters][property].clone)
          end
        end

        if resource[:parameters].include?(:content)
          resource[:parameters][:content] = { :checksum => Digest::MD5.hexdigest(resource[:parameters][:content]), :content => resource[:parameters][:content] }
        end

        resource[:resource_id] = "#{bucket.type.downcase}[#{bucket.name}]"
        collector << resource
      end
    end

    # Converts Puppet 0.25 and 2.6.x catalogs to our intermediate format
    def convert25(resource, collector)
      if resource.class == Puppet::Resource::Catalog
        resource.edges.each do |b|
          convert25(b, collector)
        end
      elsif resource.class == Puppet::Relationship and resource.target.class == Puppet::Resource and resource.target.title != nil and resource.target.file != nil
        target = resource.target
        manifestfile = target.file.gsub("/etc/puppet/manifests/", "")

        resource = {:type => target.type,
          :title => target.title,
          :parameters => {}}

        target.each do |param, value|
          resource[:parameters][param] = value
        end

        if resource[:parameters].include?(:content)
          resource[:parameters][:content] = { :checksum => Digest::MD5.hexdigest(resource[:parameters][:content]), :content => resource[:parameters][:content] }
        end

        resource[:resource_id] = "#{target.type.downcase}[#{target.title}]"
        collector << resource
      end
    end
  end
end

################# end methods to generate intermediate format ##################
