# = Define: sensu::config
#
# Defines Sensu check configurations
#
# == Parameters
#
# [*ensure*]
#   String. Whether the check should be present or not
#   Default: present
#   Valid values: present, absent
#
# [*config*]
#   Hash.  Check configuration for the client to use
#   Default: undef
#
# [*event*]
#   Hash.  Configuration to send with the event to handlers
#   Default: undef
#
define sensu::config (
  Enum['present','absent'] $ensure = 'present',
  Optional[Hash] $config = undef,
  Optional[Hash] $event  = undef,
) {

  file { "/etc/sensu/conf.d/checks/config_${name}.json":
    ensure => $ensure,
    owner  => 'sensu',
    group  => 'sensu',
    mode   => '0444',
    before => Sensu_check_config[$name],
  }

  sensu_check_config { $name:
    ensure => $ensure,
    config => $config,
    event  => $event,
    notify => Class['sensu::client::service'],
  }

}
