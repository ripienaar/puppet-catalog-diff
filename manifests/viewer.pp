class catalog_diff::viewer (
  $remote   = 'https://github.com/camptocamp/puppet-catalog-diff-viewer.git',
  $password = 'puppet',
  $revision = 'master',
) {
  require git

  class {'apache':
    default_vhost_ensure     => false,
    default_ssl_vhost_ensure => false,
  }

  apache::listen { '1495': }

  apache::vhost { 'catalog-diff-website':
    ip          => $::ipaddress,
    docroot     => '/var/www/diff',
    ip_based    => true,
    directories => [
      { path           => '/var/www/diff',
        auth_type      => 'basic',
        auth_name      => 'Catalog Diff',
        auth_user_file => '/var/www/.htpasswd',
        auth_require   => 'valid-user',
      },
    ],
    require     => Htpasswd['puppet'],
  }

  htpasswd { 'puppet':
    username    => 'puppet',
    cryptpasswd => ht_sha1($password),
    target      => '/var/www/.htpasswd',
    require     => Class['apache'],
  }

  vcsrepo { '/var/www/diff':
    ensure   => latest,
    provider => 'git',
    source   => $remote,
    revision => $revision,
    require  => Class['apache'],
  }
}
