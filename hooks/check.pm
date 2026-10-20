#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Check::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info load_yaml_file/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $ops_dir = $env->lookup('genesis.ops_dir', 'ops');

  # Check if the ops files exist for all features
  $env->notify("checking ops files for requested features...");

  foreach my $feature ($env->features) {
    if ($feature eq 'resolute') {
      info("  - feature #G{%s}: provided by the kit [#G{OK}]", $feature);
      next;
    }
    if (-f $env->path("$ops_dir/$feature.yml")) {
      info("  - feature #G{%s}: ops file exists [#G{OK}]", $feature);
    } else {
      $env->notify(error => "  - feature #R{%s}: ops file missing [#R{FAILED}]", $feature);
      $self->{ok} = 0;
    }
  }

  $self->validate_properties();

  # Return the final result
  if ($self->{ok}) {
    $env->notify(success => "environment files [#G{OK}]");
  } else {
    $env->notify(error => "environment files [#R{FAILED}]");
  }

  return $self->done($self->{ok});
}

# An optional spec/<type>-properties.yml in the deployment repo lists the
# params that every environment must set, under a top-level required: key.
sub validate_properties {
  my ($self) = @_;
  my $env = $self->env;
  my $spec_file = $env->path(sprintf("spec/%s-properties.yml", $env->type));
  return unless -f $spec_file;

  my $spec = load_yaml_file($spec_file);
  my $params = $env->lookup('params', {});
  foreach my $prop (@{$spec->{required} || []}) {
    if (!exists $params->{$prop}) {
      $env->notify(error => "Missing required property: params.%s", $prop);
      $self->{ok} = 0;
    }
  }
}

1;
