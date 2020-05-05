require 'puppet/face'
require 'thread'
require 'digest'
# require 'puppet/application/master'

Puppet::Face.define(:catalog, '0.0.1') do
  action :pull do
    description 'Pull catalogs from duel puppet masters'
    arguments '/tmp/old_catalogs /tmp/new_catalogs'

    option '--old_server=' do
      required
      summary 'This the valid certificate name or alt name for your old server'
    end

    option '--new_server=' do
      summary 'This the valid certificate name or alt name for your old server'

      default_to { Facter.value('fqdn') }
    end

    option '--threads' do
      summary 'The number of threads to use'
      default_to { '10' }
    end

    option '--use_puppetdb' do
      summary 'Use puppetdb to do the fact search instead of the rest api'
    end

    option '--[no-]filter_old_env' do
      summary "Whether to filter nodes on the old server's environment in PuppetDB"
    end

    option '--old_catalog_from_puppetdb' do
      summary 'Get old catalog from PuppetDB inside of compile master'
    end

    option '--new_catalog_from_puppetdb' do
      summary 'Get new catalog from PuppetDB inside of compile master'
    end

    option '--filter_local' do
      summary 'Use local YAML node files to filter out queried nodes'
    end

    option '--changed_depth=' do
      summary 'The number of problem files to display sorted by changes'

      default_to { '10' }
    end

    option '--certless' do
      summary 'Use the certless catalog API (Puppet >= 6.3.0)'
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

    when_invoked do |catalog1, catalog2, args, options|
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'searchfacts.rb'))
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'compilecatalog.rb'))
      nodes = Puppet::CatalogDiff::SearchFacts.new(args).find_nodes(options)
      raise "Problem finding nodes with query #{args}" unless nodes

      total_nodes = nodes.size
      thread_count = options[:threads].to_i
      compiled_nodes = []
      failed_nodes = {}
      mutex = Mutex.new

      Array.new(thread_count) {
        Thread.new(nodes, compiled_nodes, options) do |nodes, compiled_nodes, options|
          Puppet.debug(nodes)
          while node_name = mutex.synchronize { nodes.pop }
            begin
              if nodes.size.odd?
                old_server = Puppet::Face[:catalog, '0.0.1'].seed(
                  catalog1, node_name,
                  master_server: options[:old_server],
                  certless: options[:certless],
                  catalog_from_puppetdb: options[:old_catalog_from_puppetdb]
                )
                new_server = Puppet::Face[:catalog, '0.0.1'].seed(
                  catalog2, node_name,
                  master_server: options[:new_server],
                  certless: options[:certless],
                  catalog_from_puppetdb: options[:new_catalog_from_puppetdb]
                )
              else
                new_server = Puppet::Face[:catalog, '0.0.1'].seed(
                  catalog2, node_name,
                  master_server: options[:new_server],
                  certless: options[:certless],
                  catalog_from_puppetdb: options[:new_catalog_from_puppetdb]
                )
                old_server = Puppet::Face[:catalog, '0.0.1'].seed(
                  catalog1, node_name,
                  master_server: options[:old_server],
                  certless: options[:certless],
                  catalog_from_puppetdb: options[:old_catalog_from_puppetdb]
                )
              end
              mutex.synchronize { compiled_nodes + old_server[:compiled_nodes] }
              mutex.synchronize { compiled_nodes + new_server[:compiled_nodes] }
              mutex.synchronize do
                new_server[:failed_nodes][node_name].nil? ||
                  failed_nodes[node_name] = new_server[:failed_nodes][node_name]
              end
            rescue Exception => e
              Puppet.err(e.to_s)
            end
           end
        end
      }.each(&:join)
      output = {}
      output[:failed_nodes]         = failed_nodes
      output[:failed_nodes_total]   = failed_nodes.size
      output[:compiled_nodes]       = compiled_nodes.compact
      output[:compiled_nodes_total] = compiled_nodes.compact.size
      output[:total_nodes]          = total_nodes
      output[:total_percentage]     = (failed_nodes.size.to_f / total_nodes.to_f) * 100
      problem_files = {}

      failed_nodes.each do |node_name, error|
        # Extract the filename and the node a key of the same name
        match = /(\S*(\/\S*\.pp|\.erb))/.match(error.to_s)
        if match
          (problem_files[match[1]] ||= []) << node_name
        else
          unique_token = Digest::MD5.hexdigest(error.to_s.gsub(node_name, ''))
          (problem_files["No-path-in-error-#{unique_token}"] ||= []) << node_name
        end
      end

      most_changed = problem_files.sort_by { |_file, nodes| nodes.size }.map do |file, nodes|
        Hash[file => nodes.size]
      end

      output[:failed_to_compile_files] = most_changed.reverse.take(options[:changed_depth].to_i)

      example_errors = output[:failed_to_compile_files].map do |file_hash|
        example_error = file_hash.map { |file_name, _metric|
          example_node = problem_files[file_name].first
          error = failed_nodes[example_node].to_s
          Hash[error => example_node]
        }.first
        example_error
      end
      output[:example_compile_errors] = example_errors
      output
    end
    when_rendering :console do |output|
      require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'catalog-diff', 'formater.rb'))
      format = Puppet::CatalogDiff::Formater.new
      output.map { |key, value|
        if value.is_a?(Array) && key == :failed_to_compile_files
          format.list_file_hash(key, value)
        elsif value.is_a?(Array) && key == :example_compile_errors
          format.list_error_hash(key, value)
        end
      }.join("\n")
    end
  end
end
