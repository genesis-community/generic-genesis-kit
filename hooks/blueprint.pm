#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Blueprint::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail info/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  return 1 if $self->completed;

  my $env = $self->env;
  my $ops_dir = $self->ops_dir;
  my $type = $env->type;

  # The deployment repo supplies the manifest, as ops/base.yml or as
  # ops/<type>.yml, where <type> is the name given to `genesis init`.
  my $base_ops_yml;
  if (-f $env->path("$ops_dir/base.yml")) {
    $base_ops_yml = "$ops_dir/base.yml";
  } elsif ($type && -f $env->path("$ops_dir/$type.yml")) {
    $base_ops_yml = "$ops_dir/$type.yml";
  } else {
    bail(
      "#R{[ERROR]} Missing base operations file in %s/ - expecting either base.yml or %s.yml.",
      $ops_dir, $type || '<type>'
    );
  }

  $self->add_files('base.yml', $env->path($base_ops_yml));

  # Every other feature names an ops file in the deployment repo.  The
  # resolute feature is the kit's own, though the repo may still add an
  # ops/resolute.yml to go with it.
  my $abort = 0;
  for my $feature ($self->features) {
    my $ops_file = $env->path("$ops_dir/$feature.yml");
    if (-f $ops_file) {
      $self->add_files($ops_file);
    } elsif ($feature ne 'resolute') {
      $abort = 1;
      info("#R{[ERROR]} The #c{%s} feature is invalid. See the ops directory for list of valid features.", $feature);
    }
  }

  bail(
    "#R{Cannot continue} - fix your #C{%s.yml} file to resolve these issues.",
    $env->name
  ) if $abort;

  $self->_process_resolute;

  return $self->done(1);
}

sub _process_resolute {
  my ($self) = @_;

  if ($self->want_feature('resolute')) {
    my $stemcell_os = $self->env->lookup('params.stemcell_os', 'ubuntu-resolute');
    bail(
      "The #c{resolute} feature sets the stemcell os to ubuntu-resolute, but " .
      "the environment sets #c{params.stemcell_os} to #R{%s}.  " .
      "Remove that parameter.", $stemcell_os
    ) if $stemcell_os ne 'ubuntu-resolute';
    $self->add_files('manifests/resolute.yml');
  } elsif ($self->env->lookup('params.stemcell_os', 'ubuntu-jammy') eq 'ubuntu-resolute') {
    bail(
      "The environment sets #c{params.stemcell_os} to ubuntu-resolute " .
      "without the #c{resolute} feature.  Enable the feature and remove " .
      "that parameter."
    );
  }
}

1;
