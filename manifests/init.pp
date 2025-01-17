# == Class: composer
#
# The parameters for the composer class and corresponding definitions
#
# === Parameters
#
# Document parameters here.
#
# [*target_dir*]
#   The target dir that composer should be installed to.
#   Defaults to ```/usr/local/bin```.
#
# [*composer_file*]
#   The name of the composer binary, which will reside in ```target_dir```.
#
# [*download_method*]
#   Either ```curl``` or ```wget```.
#
# [*logoutput*]
#   If the output should be logged. Defaults to FALSE.
#
# [*tmp_path*]
#   Where the composer.phar file should be temporarily put.
#
# [*php_package*]
#   The Package name of tht PHP CLI package.
#
# [*curl_package*]
#   The name of the curl package to override the default set in the
#   composer::params class.
#
# [*wget_package*]
#   The name of the wget package to override the default set in the
#   composer::params class.
#
# [*composer_home*]
#   Folder to use as the COMPOSER_HOME environment variable. Default comes
#   from our composer::params class which derives from our own $composer_home
#   fact. The fact returns the current users $HOME environment variable.
#
# [*php_bin*]
#   The name or path of the php binary to override the default set in the
#   composer::params class.
#
# [*suhosin_enabled*]
#   If the suhosin mod is enabled. This requires setting php.ini
#   values with augeas
#
# [*auto_update*]
#   If the composer binary should automatically be updated on each run
#
# [*user*]
#   The user name to exec the composer commands as. Default is undefined.
#
# === Authors
#
# Thomas Ploch <profiploch@gmail.com>
#
class composer(
  Stdlib::AbsolutePath $target_dir    = $composer::params::target_dir,
  String $composer_file               = $composer::params::composer_file,
  String $download_method             = $composer::params::download_method,
  Boolean $logoutput                  = $composer::params::logoutput,
  Stdlib::AbsolutePath $tmp_path      = $composer::params::tmp_path,
  String $php_package                 = $composer::params::php_package,
  String $curl_package                = $composer::params::curl_package,
  String $wget_package                = $composer::params::wget_package,
  Stdlib::AbsolutePath $composer_home = $composer::params::composer_home,
  String $php_bin                     = $composer::params::php_bin,
  Boolean $suhosin_enabled            = $composer::params::suhosin_enabled,
  Boolean $auto_update                = $composer::params::auto_update,
  Optional[Hash] $projects            = undef,
  Optional[Hash] $execs               = undef,
  Optional[String] $github_token      = undef,
  Optional[String] $user              = undef,
) inherits ::composer::params {

  require ::stdlib
  require ::git

  # Set the exec path for composer target dir
  Exec { path => "/bin:/usr/bin/:/sbin:/usr/sbin:${target_dir}" }

  # Only install php package if it's not defined
  if defined(Package[$php_package]) == false {
    package { $php_package: ensure => present, }
  }

  # download composer
  case $download_method {
    'curl': {
      $download_command = "curl -sS https://getcomposer.org/installer | ${composer::php_bin} -- --install-dir=${tmp_path} --filename=${composer_file}"
      $download_require = $suhosin_enabled ? {
        false    => [ Package['curl', $php_package] ],
        default  => [
          Package['curl', $php_package],
          Augeas['allow_url_fopen', 'whitelist_phar']
        ],
      }
      $method_package = $curl_package
    }
    'wget': {
      $download_command = "wget https://getcomposer.org/composer.phar -O ${composer_file}"
      $download_require = $suhosin_enabled ? {
        false   => [ Package['wget', $php_package] ],
        default => [
          Package['wget', $php_package],
          Augeas['allow_url_fopen', 'whitelist_phar']
        ],
      }
      $method_package = $wget_package
    }
    default: {
      fail(
        "The param download_method ${download_method} is not valid.
        Please set download_method to curl or wget."
      )
    }
  }

  if defined(Package[$method_package]) == false {
    package { $method_package: ensure => present, }
  }

  # check if directory exists
  if defined(File[$target_dir]) == false {
    file { $target_dir:
      ensure => directory,
    }
  }

  # download composer if target_file doesn't exist
  exec { "download_composer":
    command     => $download_command,
    cwd         => $tmp_path,
    require     => $download_require,
    creates     => "${tmp_path}/${composer_file}",
    logoutput   => $logoutput,
    onlyif      => "test ! -f ${target_dir}/${composer_file}",
    path        => [ '/bin', '/usr/bin' ],
    notify      => Exec["move_composer_${target_dir}"],
    environment => ["COMPOSER_HOME=${composer::composer_home}"]
  }

  # move downloaded file to target_dir
  exec { "move_composer_${target_dir}":
    command     => "mv ${tmp_path}/${composer_file} ${target_dir}/${composer_file}; chmod 0755 ${target_dir}/${composer_file}",
    refreshonly => true,
  }

  if $auto_update == true {
    composer::selfupdate {'auto_update': }
  }

  if $suhosin_enabled == true {
    case $composer::params::family {

      'Redhat','Centos': {

        # set /etc/php5/cli/php.ini/suhosin.executor.include.whitelist = phar
        augeas { 'whitelist_phar':
          context => '/files/etc/suhosin.ini/suhosin',
          changes => 'set suhosin.executor.include.whitelist phar',
          require => Package[$php_package],
        }

        # set /etc/cli/php.ini/PHP/allow_url_fopen = On
        augeas{ 'allow_url_fopen':
          context => '/files/etc/php.ini/PHP',
          changes => 'set allow_url_fopen On',
          require => Package[$php_package],
        }
      }

      'Debian': {

        # set /etc/php5/cli/php.ini/suhosin.executor.include.whitelist = phar
        augeas { 'whitelist_phar':
          context => '/files/etc/php5/conf.d/suhosin.ini/suhosin',
          changes => 'set suhosin.executor.include.whitelist phar',
          require => Package[$php_package],
        }

        # set /etc/php5/cli/php.ini/PHP/allow_url_fopen = On
        augeas { 'allow_url_fopen':
          context => '/files/etc/php5/cli/php.ini/PHP',
          changes => 'set allow_url_fopen On',
          require => Package[$php_package],
        }
      }

      'FreeBSD': {
        # set /usr/local/etc/php/suhosin.ini/suhosin.executor.include.whitelist = phar
        augeas { 'whitelist_phar':
          context => '/files/usr/local/etc/php/suhosin.ini/suhosin',
          changes => 'set suhosin.executor.include.whitelist phar',
          require => Package[$php_package],
        }

        # set /usr/local/etc/php.ini/PHP/allow_url_fopen = On
        augeas { 'allow_url_fopen':
          context => '/files/usr/local/etc/php.ini/PHP',
          changes => 'set allow_url_fopen On',
          require => Package[$php_package],
        }
      }

      default: {}
    }
  }

  $composer_path = "${target_dir}/${composer_file}"
  $github_config = 'config -g github-oauth.github.com'

  if $github_token {
    Exec {
      environment => "COMPOSER_HOME=${composer_home}",
    }
    exec { 'setup_github_token':
      command => "${composer_path} ${github_config} ${github_token}",
      cwd     => $tmp_path,
      require => File["${target_dir}/${composer_file}"],
      user    => $user,
      unless  => "${composer_path} ${github_config}|grep ${github_token}",
    }
  }

  if $composer::projects or $composer::execs {
    class {'composer::project_factory' :
      projects => $composer::projects,
      execs    => $composer::execs,
    }
  }
}
