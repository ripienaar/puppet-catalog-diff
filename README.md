# Puppet Catalog Diff

[![Puppet Forge Version](http://img.shields.io/puppetforge/v/camptocamp/catalog_diff.svg)](https://forge.puppetlabs.com/camptocamp/catalog_diff)
[![Puppet Forge Downloads](http://img.shields.io/puppetforge/dt/camptocamp/catalog_diff.svg)](https://forge.puppetlabs.com/camptocamp/catalog_diff)
[![Build Status](https://img.shields.io/travis/camptocamp/puppet-catalog-diff/master.svg)](https://travis-ci.org/camptocamp/puppet-catalog-diff)
[![By Camptocamp](https://img.shields.io/badge/by-camptocamp-fb7047.svg)](http://www.camptocamp.com)

## Overview

A tool to compare two Puppet catalogs.

While upgrading versions of Puppet or refactoring Puppet code you want to
ensure that no unexpected changes will be made prior to committing the changes.

This tool will allow you to diff catalogs created by different versions of
Puppet or different environments.
This will let you gauge the impact of a change before actually touching
any of your nodes.

This tool is delivered as a collection of Puppet Faces.
It thus requires a Puppet installation to properly run.

The diff tool recognizes catalogs in yaml, marshall, json, or pson formats.
Currently automatic generation of the catalogs is done in the pson format.

The tool can automatically compile the catalogs for both your new and older
servers/environments.
It can ask the master to use PuppetDB to compile the catalog for the last
known environment with the last known facts. It can then validate against PuppetDB
that the node is still active. This filtered list
should contain only machines that have not been decommissioned in PuppetDB (important
as compiling their catalogs would also reactive them and their exports otherwise).


## Usage


### Set up node discovery


Node discovery requires an access to the PuppetDB. You'll need either:

* have an unencrypted access to PuppetDB (port 8080, local or proxified)
* generate a set key and certificate signed by the Puppet CA to access the
  PuppetDB


### Set up auth.conf


Once you have set up the discovery, you need to allow access to the "diff" node to
compile the catalogs for all nodes on both your old and new masters.

On Puppet 5+, you need to edit the Puppetserver's
`/etc/puppetlabs/puppetserver/conf.d/auth.conf` file.

In your confdir modify auth.conf to allow access to `/catalog`.
If there is an existing reference i.e. the $1 back reference for machines to
compile their own catalog then simply add another line with the certificate
name of the diff machine. As mentioned this can be the new master as required.


E.g. if you're using Puppet 5, you should have something like:

```ruby
{
    # Allow nodes to retrieve their own catalog
    match-request: {
        path: "^/puppet/v3/catalog/([^/]+)$"
        type: regex
        method: [get, post]
    }
    allow: ["$1","catalog-diff"]
    sort-order: 500
    name: "puppetlabs catalog"
},
```


If you are on Puppet 6, you can activate the certless API instead with:

```ruby
{
    match-request: {
        path: "^/puppet/v4/catalog"
        type: regex
        method: [post]
    }
    allow: ["catalog-diff"]
    sort-order: 500
    name: "puppetlabs certless catalog"
},
```


### Running


Example:


```shell
$ puppet module install camptocamp-catalog-diff
$ puppet catalog diff \
     puppet5.example.com:8140/production puppet6.example.com:8140/production \
     --use_puppetdb \
     --filter_old_env \
     --old_catalog_from_puppetdb \
     --certless \
     --show_resource_diff \
     --content_diff \
     --ignore_parameters alias \  # Puppet6 removes lots of alias parameters
     \ #--yamldir $YAMLDIR \
     \ #--ssldir $SSLDIR \
     --changed_depth 1000 \
     --configtimeout 1000 \
     --output_report "${HOME}/lastrun-$$.json" \
     --debug \
     \ #--fact_search kernel='Darwin' \
     --threads 50
```


### Multi threaded compile requests

You can change the number of concurrent connections to the masters by passing an interger
to the `--threads` option. This will balence the catalogs evenly on the old and new
masters. This option defaults to 10 and in testing 50 threads seemed correct for
4 masters with two load balancers.

Note: When using catalog diff to compare directories, one thread per catalog
comparison will be created.  However, since Ruby cannot take advantage of
multiple CPUs this may be of limited use comparing local catalogs.  If the
'parallel' gem is installed, then one process will be forked off per CPU on the
system, allowing use of all CPUs.

### Fact search

You can pass `--fact_search` to filter the list of nodes based on a single fact value.
This currently defaults to `kernel=Linux` if you do not pass it.
This query will be passed as a filter to the PuppetDB to retrieve the list of
nodes to compare.

### Changed depth

Once each catalog is compiled , it is saved to the /tmp directory on the system and the
face will then automatically calculate the differences between the catalogs. Once this
is complete a summary of number of nodes with changes as well as nodes whose catalog
would not compile are listed. You can modify the number of nodes shown here using
`--changed_depth` option.

### Output Report

You can save the last report as json to a specific location using "`--output_report`"
This report will contain the structured data in the format of running this command
with `--render-as json`. An example Rakefile is provided with a `docs` task for
converting this report to (GitHub flavored) markdown. The script above also will
save the output with escaped color. If you want to view that text report run
`less -r lastrun-$$.log`


### Limitations

This code only validates the catalogs, it cannot tell you if the behavior of
the providers that interpret the catalog has changed so testing is still
recommended, this is just one tool to take away some of the uncertainty.

You can get some inline help with:

    puppet man catalog

The reports generated by this tool can be rendered as json as well as
viewed in markdown using the Rakefile in this directory.
A web viewer is also available at [https://github.com/camptocamp/puppet-catalog-diff-viewer](https://github.com/camptocamp/puppet-catalog-diff-viewer)


## Authors
R.I.Pienaar <rip@devco.net> / www.devco.net / @ripienaar  
Zack Smith <zack@puppetlabs.com> / @acidprime  
Raphaël Pinson <raphael.pinson@camptocamp.com> / @raphink
See change log
