#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Check::Generic v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->{ok} = 1; # Start assuming all checks will pass
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $genesis_root = $ENV{GENESIS_ROOT};
  my $name = $self->env->lookup('params.name', 'generic');

  # Check if the ops files exist for all features
  $env->notify("checking ops files for requested features...");

  foreach my $feature ($self->env->features) {
    my $ops_file = "$genesis_root/ops/$feature.yml";
    if (-f $ops_file) {
      info("  - feature #G{%s}: ops file exists [#G{OK}]", $feature);
    } else {
      $env->notify(error => "  - feature #R{%s}: ops file missing [#R{FAILED}]", $feature);
      $self->{ok} = 0;
    }
  }


  $self->validate_properties();

  # Add any additional specific checks here...

  # Return the final result
  if ($self->{ok}) {
    $env->notify(success => "environment files [#G{OK}]");
  } else {
    $env->notify(error => "environment files [#R{FAILED}]");
  }

  return $self->done($self->{ok});
}

sub validate_properties {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');
  my $spec_file = "spec/$name-properties.yml";

  if (-f $spec_file) {
    my $spec = load_yaml_file($spec_file);
    my $params = $self->env->lookup('params', {});

    # Validate required properties
    foreach my $prop (@{$spec->{required} || []}) {
      if (!exists $params->{$prop}) {
        $self->env->notify(error => "Missing required property: %s", $prop);
        $self->{ok} = 0;
      }
    }
  }
}

1;
