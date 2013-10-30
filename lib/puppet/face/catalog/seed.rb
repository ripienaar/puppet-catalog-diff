require 'puppet/face'
require 'puppet/application/master'

Puppet::Face.define(:catalog, '0.0.1') do
  action :seed do
    summary "Generate a series of catalogs"
    arguments "<path/to/seed/directory>"

    option "--puppetdb" do
      summary "Not implemented:  retreive node list from puppetdb"
    end

    description <<-'EOT'
      This action is used to seed a series of catalogs to then be compared with diff
    EOT
    notes <<-'NOTES'
      This will store files in pson format with the in the save directory. i.e.
      <path/to/seed/directory>/<node_name>.pson . This is currently the only format
      that is supported.

    NOTES
    examples <<-'EOT'
      Dump host catalogs:

      $ puppet catalog seed /tmp/old_catalogs 'virtual=virtualbox'
    EOT

    when_invoked do |save_directory,args,options|
      require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "catalog-diff", "searchfacts.rb"))
      nodes = Puppet::CatalogDiff::SearchFacts.new(args).find_nodes(options)
      nodes.each do |node_name|
        unless catalog = Puppet::Resource::Catalog.indirection.find(node_name)
          raise "Could not compile catalog for #{node_name}"
        end
        catalog = PSON::pretty_generate(catalog.to_resource, :allow_nan => true, :max_nesting => false)
        Puppet.notice(catalog)
        File.open("#{save_directory}/#{node_name}.pson","w") do |f|
          f.write(catalog)
        end
      end
    end

    when_rendering :console do |output|
      output.each do |header|
        "#{header}"
      end
    end
  end
end
