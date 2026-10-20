#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Blueprint::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Blueprint);

use Genesis qw/bail warning/;

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

  # Every other feature names an ops file in the deployment repo, which the
  # features hook has already confirmed.  The resolute feature is the kit's
  # own, though the repo may still add an ops/resolute.yml to go with it.
  for my $feature ($self->features) {
    my $ops_file = $env->path("$ops_dir/$feature.yml");
    $self->add_files($ops_file) if -f $ops_file;
  }

  $self->_process_resolute;
  $self->_check_stemcell_version;

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

# base.yml reads params.stemcell_version first and meta.stemcell_version
# second, so a stale params value in a parent file now wins over meta.
sub _check_stemcell_version {
  my ($self) = @_;
  my $params_version = $self->env->lookup('params.stemcell_version', undef);
  my $meta_version   = $self->env->lookup('meta.stemcell_version', undef);
  warning(
    "The environment sets #c{params.stemcell_version} to #y{%s} and " .
    "#c{meta.stemcell_version} to #y{%s}.  The kit deploys the params value, " .
    "so remove whichever one is stale.", $params_version, $meta_version
  ) if defined($params_version) && defined($meta_version) && "$params_version" ne "$meta_version";
}

1;
