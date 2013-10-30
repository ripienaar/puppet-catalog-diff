module Puppet::CatalogDiff
  class FindCatalogs

    attr_accessor :old_catalog_path, :new_catalog_path

    def initialize(old_catalog_path, new_catalog_path)
      @old_catalog_path = old_catalog_path
      @new_catalog_path = new_catalog_path
    end

    def find_catalogs(catalog_path)
      found_catalogs = []
      Dir.glob("#{catalog_path}/*.{yaml,marshal,pson,json}") do |catalog_file|
        found_catalogs << catalog_file
      end
      Puppet.debug("Found catalogs #{found_catalogs.size} in #{catalog_path}")
      found_catalogs
    end

    def return_filename_hash(paths)
      # create a hash of the results with the filename as the key
      results_hash = {}
      paths.each do |path|
        filename = File.basename(path)
        results_hash[filename] = path
      end
      results_hash
    end

    def return_matching_catalogs(old_results,new_results)
      # return a hash with new_path => old_path for all matching results
      new_results = return_filename_hash(new_results)
      old_results = return_filename_hash(old_results)
      matching_catalogs = {}
      new_results.each do |filename,new_path|
        if old_results.has_key?(filename)
          Puppet.debug("Found matching catalog for #{new_path}")
          matching_catalogs[new_path] = old_results[filename]
        else
          Puppet.err("Missing partner catalog for #{filename}")
        end
      end
      matching_catalogs
    end

    def return_catalogs(options = {})
      old = find_catalogs(old_catalog_path)
      new = find_catalogs(new_catalog_path)
      return_matching_catalogs(old,new)
    end
  end
end
