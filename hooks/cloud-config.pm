#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::CloudConfig::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

use parent qw(Genesis::Hook::CloudConfig);

use Genesis::Hook::CloudConfig::Helpers qw/gigabytes megabytes/;

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  # Get the name from environment to use as the network/vm/disk name
  my $name = $self->env->lookup('params.name', 'generic');

  my $config = $self->build_cloud_config({
    'networks' => [
      $self->network_definition($name, strategy => 'ocfp',
        dynamic_subnets => {
          allocation => {
            size => 0,
            statics => 0,
          },
          cloud_properties_for_iaas => {
            openstack => {
              'net_id' => $self->network_reference('id'),
              'security_groups' => ['default']
            },
            pve => {
              'bridge' => $self->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0'),
            },
          },
        },
      )
    ],
    'vm_types' => [
      $self->vm_type_definition($name,
        cloud_properties_for_iaas => {
          openstack => {
            'instance_type' => $self->for_scale({
              dev => 'm1.2',
              prod => 'm1.3'
            }, 'm1.2'),
            'boot_from_volume' => $self->TRUE,
            'root_disk' => {
              'size' => 32 # in gigabytes
            },
          },
          pve => {
            'cpu'            => scalar($self->env->lookup('bosh-configs.cpi.pve_generic_cpu',  $self->for_scale({dev => 2, prod => 4}, 2))),
            'ram'            => scalar($self->env->lookup('bosh-configs.cpi.pve_generic_ram',  $self->for_scale({dev => 4096, prod => 8192}, 4096))),
            'disk'           => scalar($self->env->lookup('bosh-configs.cpi.pve_generic_disk', $self->for_scale({dev => 32768, prod => 65536}, 32768))),
            'network_bridge' => $self->_pve_cpi_setting('pve_network_bridge', 'network_bridge', 'vmbr0'),
          },
        },
      ),
    ],
    'disk_types' => [
      $self->disk_type_definition($name,
        common => {
          disk_size => $self->for_scale({
            dev => gigabytes(64),
            prod => gigabytes(128)
          }, gigabytes(64)),
        },
        cloud_properties_for_iaas => {
          openstack => {
            'type' => 'storage_premium_perf6',
          },
          pve => {
            'storage'     => $self->_pve_cpi_setting('pve_disk_storage', 'disk_storage', 'local-lvm'),
            'disk_format' => scalar($self->env->lookup('bosh-configs.cpi.pve_disk_format', 'raw')),
          },
        },
      ),
    ],
  });

  $self->done($config);
}

# Resolves a PVE CPI setting from the env file, then the OCFP vault config,
# and then a default.
sub _pve_cpi_setting {
  my ($self, $env_key, $vault_key, $default) = @_;
  my $value = scalar($self->env->lookup("bosh-configs.cpi.$env_key", undef));
  $value //= scalar($self->env->ocfp_config_lookup("cpi.pve.$vault_key", undef));
  $value //= $default;
  bail(
    "No PVE %s configured for %s.  Set #c{bosh-configs.cpi.%s} in the " .
    "environment file, or run #g{ocfp vault populate} so that the OCFP " .
    "config provides #c{cpi/pve:%s}.",
    $vault_key, $self->env->name, $env_key, $vault_key
  ) unless defined($value) && length($value);
  return $value;
}

1;
