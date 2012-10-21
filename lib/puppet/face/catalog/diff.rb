require 'puppet/face'

Puppet::Face.define(:catalog, '0.0.1') do
  action :diff do
    summary "Compare catalogs from different puppet versions."
    arguments "<catalog1> <catalog2>"

    option "--content_diff" do
      summary "Whether to show a diff for File resource content"
    end

    description <<-'EOT'
      Prints the differences between catalogs compiled by different puppet master to help
      during migrating to a new Puppet version.
    EOT
    notes <<-'NOTES'
      The diff tool recognizes catalogs in yaml, marshall, or pson format.

      Validation Process:

       - Grab a catalog from your existing machine running the old version
       - Configure your new Puppet master, copy the facts from your old master
         to the new one
       - Compile the catalog for this host on the new master:

            puppet master --compile fqdn > fqdn.pson

       - Puppet puts a header in some catalogs compiled in this way, remove it if present
       - At this point you should have 2 different catalogs. To compare them run:

            puppet catalog diff <catalog1> <catalog2>


      Example Output:

      During the transition of 0.24.x to 0.25.x there was a serialization bug
      that resulted in unexpected file content changes, I've recreated this bug
      in a tiny 2 resource catalog, the output below shows how this tool would
      have highlighted this bug prior to upgrading any nodes.

        Resource counts:
          Old: 2
          New: 2

        Catalogs contain the same resources by resource title


        Individual Resource differences:
        Old Resource:
          file{"/tmp/foo":
             content => d3b07384d113edec49eaa6238ad5ff00
          }

        New Resource:
          file{"/tmp/foo":
             content => dbb53f3699703c028483658773628452
          }

      Had resources simply gone missing - not the case here - you would have seen
      a list of that.

      This code only validates the catalogs, it cannot tell you if the behavior of
      the providers that interpret the catalog has changed so testing is still
      recommended, this is just one tool to take away some of the uncertainty

    NOTES
    examples <<-'EOT'
      Compare host catalogs:

      $ puppet catalog diff host-2.6.yaml host-3.0.pson
    EOT

    when_invoked do |catalog1, catalog2, options|
      require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "catalog-diff", "differ.rb"))

      Puppet::CatalogDiff::Differ.new(catalog1, catalog2).diff(options)
    end
  end
end
