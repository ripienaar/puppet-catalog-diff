# Overview
A tool to compare two Puppet catalogs.

While upgrading versions of Puppet or refactoring Puppet code you want to
ensure that no unexpected changes will be made prior to doing the upgrade.

This tool will allow you to diff catalogs created by different versions of
Puppet.  This will let you guage the impact of a Puppet upgrade before actually
touching any of your nodes.

This tool is delivered as a Puppet Face. It thus requires a Puppet installation
to properly run.

The diff tool recognizes catalogs in yaml, marshall, or pson format. Currently automatic
generation of the catalogs is done in the pson format.

The tool can automatically compile the catalogs for both your new and older servers.
It can ask the master to use the yaml cache to compile the catalog for the last
known environment with the last known facts. It can then validate against the rest
terminus ( or by proxy puppetdb ) that the node is still active. This filtered list
should contain only machines that have not been decommissioned in puppetdb (important
as compiling their catalogs would also reactive them and their exports otherwise).

# Usage
Before starting you need to copy or mount the contents of your current master's
yamldir on the diff node, new master and old master.If you have multiple masters then combine
the yamldirs of all nodes to give the fullest picture of all catalogs


You can retrieve the current yamldir location with the following command:
`puppet master --configprint yamldir`. If you are using  Puppet
Enterprise this directory is '/var/opt/lib/pe-puppet/yaml'. It is not required
to use a specific "diff" node , as you could use the "new" puppet server.

Once the yamldir is in place you need to allow access to the "diff" node to
compile the catalogs for all nodes on both your old and new masters.
In your confdir modify auth.conf to add allows for both /facts and /catalog.
If there is an existing reference i.e. the $1 back reference for machines to
compile their own catalog then simply add another line with the certificate
name of the diff machine. As mentioned this can be the new master as required.

~~~
# allow the diff server to query facts
path  /facts
method find, search
auth any
allow diff.example.com
~~~

~~~
# allow the diff server to retrieve any catalog
path ~ ^/catalog/([^/]+)$
method find
allow $1
allow diff.example.com
~~~

The /facts ACL is optional onlly if you are using puppetdb and running the query
from the master. You can pass `--use_puppetdb` to query the puppetdb server
directly rather than via the rest terminus. However the rest terminus should
be the same list of nodes if they are both backed by puppetdb and so this
option is only for environments where puppetdb is more authoritative in some
way they the facts rest query. This option is provided for future compatibility.

You can run this face without root access if you run the script as the puppet user
on the system. The following is an example script doing so. You can alternatively
install this in your module path on Puppet 3 and higher without the need of
exporting RUBYLIB. One example of when you would need to run this as non
root would be if you mounted the yamldir via NFS and had root squash enabled.

```shell
#!/bin/bash -x
if !-d "${HOME}/puppet-catalog-diff" ; then
  git clone https://github.com/acidprime/puppet-catalog-diff.git
fi

# These should be changed for Puppet Enterprise
export RUBYLIB="${HOME}/puppet-catalog-diff/lib/"
export YAMLDIR='/var/lib/puppet/yaml'
export SSLDIR='/var/lib/puppet/ssl'
export PUSER='puppet'
[ $USER == $PUSER ] || exit 1
time puppet catalog diff puppet2.example.com puppet3.example.com \
--show_resource_diff \
--content_diff \
--yamldir $YAMLDIR \
--ssldir $SSLDIR \
--changed_depth 1000 \
--configtimeout 1000 \
--output_report "${HOME}/lastrun-$$.json" \
--debug \
\ #--fact_search kernel='Darwin' \
--threads 50 | tee -a lastrun-$$.log
```
## Multi threaded compile requests
You can change the number of concurrent connections to the masters by passing an interger
to the `--threads` option. This will balence the catalogs evenly on the old and new
masters. This option defaults to 10 and in testing 50 threads seemed correct for
4 masters with two load balancers.

Note: When using catalog diff to compare directories, one thread per catalog
comparison will be created.  However, since Ruby cannot take advantage of
multiple CPUs this may be of limited use comparing local catalogs.  If the
'parallel' gem is installed, then one process will be forked off per CPU on the
system, allowing use of all CPUs.

## Fact search
You can pass `--fact_search` to filter the list of nodes based on a single fact value.
This currently defaults to `kernel=Linux` if you do not pass it. The yaml cache will be
queried to find all nodes whose fact matches that value. Once a list of nodes with known
facts is compiled a rest or puppetdb connection ( as mentioned above) filters the list
to only nodes who are "active" based typically on puppetdb. For more information on
deactiving nodes in puppetdb see [this article](http://docs.puppetlabs.com/puppetdb/latest/maintain_and_tune.html)

## Changed depth
Once each catalog is compiled , it is saved to the /tmp directory on the system and the
face will then automatically calculate the differences between the catalogs. Once this
is complete a summary of number of nodes with changes as well as nodes whose catalog
would not compile are listed. You can modify the number of nodes shown here using
`--changed_depth` option.

## Output Report
You can save the last report as json to a specific location using "`--output_report`"
This report will contain the structured data in the format of running this command
with `--render-as json`. An example Rakefile is provided with a `docs` task for
converting this report to (GitHub flavored) markdown. The script above also will
save the output with escaped color. If you want to view that text report run
`less -r lastrun-$$.log`

## Output description
During the transition of 0.24.x to 0.25.x there was a serialization bug that
resulted in unexpected file content changes. I've recreated this bug in a tiny
2 resource catalog, the output below shows how this tool would have highlighted
this bug prior to upgrading any nodes.

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

Had resources simply gone missing - not the case here - you would have seen a
list of that.

This code only validates the catalogs, it cannot tell you if the behavior of
the providers that interpret the catalog has changed so testing is still
recommended, this is just one tool to take away some of the uncertainty.

You can get some inline help with:

    puppet man catalog

The reports generated by the this tool can be rendered as json as well as
viewed in markdown using the Rakefile in this directory. A web viewer is also being developed at [https://github.com/camptocamp/puppet-catalog-diff-viewer](https://github.com/camptocamp/puppet-catalog-diff-viewer)


# Authors
R.I.Pienaar <rip@devco.net> / www.devco.net / @ripienaar  
Zack Smith <zack@puppetlabs.com> / @acidprime  
Raphaël Pinson <raphael.pinson@camptocamp.com> / @raphink
See change log
