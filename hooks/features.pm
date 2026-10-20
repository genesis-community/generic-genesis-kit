#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Features);

use Genesis qw/bail/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $ops_dir = $self->env->lookup('genesis.ops_dir', 'ops');

  # Features name ops files in the deployment repo, except for resolute,
  # which the kit provides itself.
  foreach my $feature (@{$self->{features}}) {
    if ($feature eq 'resolute' || -f $self->env->path("$ops_dir/$feature.yml")) {
      $self->add_feature($feature);
    } else {
      bail(
        "Feature [%s] is invalid. The ops file %s does not exist.",
        $feature, $self->env->path("$ops_dir/$feature.yml")
      );
    }
  }

  return $self->done();
}

1;
