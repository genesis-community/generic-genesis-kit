#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Features::Generic v1.0.0;

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
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $genesis_root = $ENV{GENESIS_ROOT};
  my $name = $self->env->lookup('params.name', 'generic');

  foreach my $feature (@{$self->{features}}) {
    if (-f "$genesis_root/ops/$feature.yml") {
      $self->add_feature($feature);
    } else {
      bail(
        "Feature [%s] is invalid. The ops file %s/ops/%s.yml does not exist.",
        $feature, $genesis_root, $feature
      );
    }
  }

  return $self->done($self->{features});
}

1;
