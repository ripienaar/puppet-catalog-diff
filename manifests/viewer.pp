class catalog_diff::viewer {
  require apache
  require git

  vcsrepo { '/var/www/html':
    ensure   => latest,
    provider => 'git',
    source   => 'https://github.com/camptocamp/puppet-catalog-diff-viewer.git',
    revision => 'master',
  }
}
