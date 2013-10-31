require 'puppet/face'
require 'thread'
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
      require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "catalog-diff", "compilecatalog.rb"))
      # If the args contains a fact search then assume its not a node_name
      if args =~ /.*=.*/
        nodes = Puppet::CatalogDiff::SearchFacts.new(args).find_nodes(options)
      else
        nodes = args.split(',')
      end
      THREAD_COUNT = 1
      compiled_nodes = []
      mutex = Mutex.new

      THREAD_COUNT.times.map {
        Thread.new(nodes,compiled_nodes) do |nodes,compiled_nodes|
          while node_name = mutex.synchronize { nodes.pop }
            compiled = Puppet::CatalogDiff::CompileCatalog.new(node_name,save_directory)
            mutex.synchronize { compiled_nodes << compiled }
          end
        end
      }.each(&:join)
    end

    when_rendering :console do |output|
      output.each do |header|
        "#{header}"
      end
    end
  end
end
