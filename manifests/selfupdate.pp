# == Type: composer::selfupdate
#
# Updates composer to the latest/given version
#
# === Parameters
#
# Document parameters here.
#
# [*version*]
#   The version to which composer should be updated/rollbacked to.
#   Leave empty for the latest version. Defaults to undefined.
#
# [*rollback*]
#   Boolean indicating wether this action is a rollback. If it's true,
#   a version *must* be defined! Defaults to FALSE.
#
# [*clean_backups*]
#   Boolean indicating wether backups should be cleaned. Defaults to FALSE
#
# [*logoutput*]
#   If the output should be logged. Defaults to FALSE.
#
# [*user*]
#   The user name to exec the composer commands as. Default is undefined.
#
# === Authors
#
# Thomas Ploch <profiploch@gmail.com>
#
# === Copyright
#
# Copyright 2013-2014 Thomas Ploch
#
define composer::selfupdate(
  Boolean $rollback          = false,
  Boolean $clean_backups     = false,
  Boolean $logoutput         = false,
  Integer $timeout           = 300,
  Integer $tries             = 3,
  Optional[String] $version  = undef,
  Optional[String] $user     = undef,
  Optional[String] $schedule = undef,
) {
  require ::composer

  if $version == undef and $rollback == true {
    fail('You cannot use rollback without specifying a version')
  }

  Exec {
    path        => "/bin:/usr/bin/:/sbin:/usr/sbin:${composer::target_dir}",
    environment => "COMPOSER_HOME=${composer::composer_home}",
    user        => $user,
  }

  $composer_path = "${composer::target_dir}/${composer::composer_file}"

  $exec_name    = "composer_selfupdate_${title}"
  $base_command = "${composer::php_bin} ${composer_path} selfupdate"

  if $version != undef {
    $version_arg = " ${version}"
  } else {
    $version_arg = ''
  }

  $rollback_arg = $rollback ? {
    true    => ' --rollback',
    default => '',
  }

  $clean_backups_arg = $clean_backups ? {
    true    => ' --clean-backups',
    default => '',
  }

  $cmd = "${base_command}${rollback_arg}${clean_backups_arg}${version_arg}"

  exec { $exec_name:
    command  => $cmd,
    tries    => $tries,
    timeout  => $timeout,
    user     => $user,
    schedule => $schedule,
  }
}
