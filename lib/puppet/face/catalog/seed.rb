require 'puppet/face'
require 'thread'
#require 'puppet/application/master'

Puppet::Face.define(:catalog, '0.0.1') do
  action :seed do
    summary "Generate a series of catalogs"
    arguments "<path/to/seed/directory> fact=CaseSensitiveValue"

    option "--master_server SERVER" do
      summary "The server from which to download the catalogs from"
      default_to { Facter.value('fqdn') }
    end

    option "--certless" do
      summary "Use the certless catalog API (Puppet >= 6.3.0)"
    end

    description <<-'EOT'
      This action is used to seed a series of catalogs to then be compared with diff
    EOT
    notes <<-'NOTES'
      This will store files in pson format with the in the save directory. i.e.
      <path/to/seed/directory>/<node_name>.pson . This is currently the only format
      that is supported. You must add --mode master currently on 2.7

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
      unless save_directory =~ /.*\/.*/
        raise "The directory path passed (#{save_directory}) is not an absolute path, mismatched arguments?"
      end
      unless File.directory?(save_directory)
        Puppet.debug("Directory did not exist, creating #{save_directory}")
        FileUtils.mkdir(save_directory)
      end
      thread_count = 10
      compiled_nodes = []
      failed_nodes = {}
      mutex = Mutex.new

      thread_count.times.map {
        Thread.new(nodes,compiled_nodes,options) do |nodes,compiled_nodes,options|
          while node_name = mutex.synchronize { nodes.pop }
            begin
              compiled = Puppet::CatalogDiff::CompileCatalog.new(node_name,save_directory,options[:master_server],options[:certless])
              mutex.synchronize { compiled_nodes << node_name }
            rescue Exception => e
              Puppet.err("Unable to compile catalog for #{node_name}\n\t#{e}")
              mutex.synchronize { failed_nodes[node_name] = e }
            end
          end
        end
      }.each(&:join)
      output = {}
      output[:compiled_nodes] = compiled_nodes
      output[:failed_nodes]   = failed_nodes

      output
    end

    when_rendering :console do |output|
      output.collect do |key|
        if key == :compiled_nodes
          key.each do |node|
            "Compiled Node: #{node}"
          end
        end
      end.join("\n") + "#{output[:failed_nodes].join("\n")}\nFailed on #{output[:failed_nodes].size} nodes"
    end
  end
end
