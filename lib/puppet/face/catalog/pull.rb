require 'puppet/face'
require 'thread'
#require 'puppet/application/master'

Puppet::Face.define(:catalog, '0.0.1') do
  action :pull do
    description "Pull catalogs from duel puppet masters"
    arguments "/tmp/old_catalogs /tmp/new_catalogs"

    option "--old_server=" do
      required
      summary "This the valid certificate name or alt name for your old server"
    end
    option "--new_server=" do
      summary "This the valid certificate name or alt name for your old server"

      default_to { 'localhost'}
    end

    description <<-'EOT'
      This action is used to seed a series of catalogs from two servers
    EOT
    notes <<-'NOTES'
      This will store files in pson format with the in the save directory. i.e.
      <path/to/seed/directory>/<node_name>.pson . This is currently the only format
      that is supported.

    NOTES
    examples <<-'EOT'
      Dump host catalogs:

      $ puppet catalog pull /tmp/old_catalogs /tmp/new_catalogs kernel=Linux --old_server puppet2.puppetlabs.vm --new_server puppet3.puppetlabs.vm
    EOT

    when_invoked do |catalog1,catalog2,args,options|
      require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "catalog-diff", "searchfacts.rb"))
      require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "catalog-diff", "compilecatalog.rb"))
      unless nodes = Puppet::CatalogDiff::SearchFacts.new(args).find_nodes(options)
        raise "Problem finding nodes with query #{args}"
      end
      thread_count = 10
      compiled_nodes = []
      failed_nodes = []
      mutex = Mutex.new

      thread_count.times.map {
        Thread.new(nodes,compiled_nodes,options) do |nodes,compiled_nodes,options|
          while node_name = mutex.synchronize { nodes.pop }
            begin
              old = Puppet::Face[:catalog, '0.0.1'].seed(catalog1,node_name,:master_server => options[:old_server] )
              new = Puppet::Face[:catalog, '0.0.1'].seed(catalog2,node_name,:master_server => options[:new_server] )
              mutex.synchronize { compiled_nodes << node_name }
            rescue Exception => e
              mutex.synchronize { failed_nodes << node_name }
            end
          end
        end
      }.each(&:join)
    end
  when_rendering :console do |output|
      "test"
    end
  end
end
