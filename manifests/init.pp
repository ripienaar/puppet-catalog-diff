class catalog_diff(
  $diff_master,
) {
  puppet_auth { 'allow the diff server to retrieve any catalog':
    ensure        => present,
    path          => '^/catalog/([^/]+)$',
    path_regex    => true,
    authenticated => 'yes',
    methods       => 'find',
    allow         => ['$1', $diff_master],
  }

  puppet_auth { 'allow the diff server to query facts':
    ensure        => present,
    path          => '/facts',
    authenticated => 'any',
    path_regex    => false,
    methods       => [ 'find', 'search'],
    allow         => ['$1', $diff_master, 'pe-internal-dashboard'],
  }
}
