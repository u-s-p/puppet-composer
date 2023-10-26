# == Type: composer::exec
#
# Either installs from composer.json or updates project or specific packages
#
# === Authors
#
# Thomas Ploch <profiploch@gmail.com>
#
# === Copyright
#
# Copyright 2013 Thomas Ploch
#
define composer::exec (
  String $cmd,
  Stdlib::AbsolutePath $cwd,
  Array $packages                             = [],
  Boolean $prefer_source                      = false,
  Boolean $prefer_dist                        = false,
  Boolean $dry_run                            = false,
  Boolean $custom_installers                  = false,
  Boolean $scripts                            = false,
  Boolean $optimize                           = false,
  Boolean $ignore_platform_reqs               = false,
  Boolean $interaction                        = false,
  Boolean $dev                                = true,
  Boolean $no_update                          = false,
  Boolean $no_progress                        = false,
  Boolean $update_with_dependencies           = false,
  Boolean $logoutput                          = false,
  Boolean $verbose                            = false,
  Boolean $refreshonly                        = false,
  Boolean $lock                               = false,
  Integer $timeout                            = undef,
  String $user                                = $composer::user,
  Boolean $global                             = false,
  Optional[Stdlib::AbsolutePath] $working_dir = undef,
  Optional[String] $onlyif                    = undef,
  Optional[String] $unless                    = undef,
) {
  require ::composer

  $m_timeout = $timeout?{
    undef => 300,
    default => $timeout
  }
  Exec {
    path        => "/bin:/usr/bin/:/sbin:/usr/sbin:${composer::target_dir}",
    environment => ["COMPOSER_HOME=${composer::composer_home}", "COMPOSER_PROCESS_TIMEOUT=${m_timeout}"],
    user        => $user,
    timeout     => $timeout
  }

  if $cmd != 'install' and $cmd != 'update' and $cmd != 'require' {
    fail(
      "Only types 'install', 'update' and 'require'' are allowed, ${cmd} given"
    )
  }

  if $prefer_source and $prefer_dist {
    fail('Only one of \$prefer_source or \$prefer_dist can be true.')
  }

  $composer_path = "${composer::target_dir}/${composer::composer_file}"

  $command = $global ? {
    true  => "${composer::php_bin} ${composer_path} global ${cmd}",
    false => "${composer::php_bin} ${composer_path} ${cmd}",
  }

  exec { "composer_${cmd}_${title}":
    command     => template("composer/${cmd}.erb"),
    cwd         => $cwd,
    logoutput   => $logoutput,
    refreshonly => $refreshonly,
    user        => $user,
    onlyif      => $onlyif,
    unless      => $unless,
  }
}
