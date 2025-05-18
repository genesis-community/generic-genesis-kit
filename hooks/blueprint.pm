#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Blueprint::Generic v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/bail info/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->{files} = [];
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my @manifest = ();

  # Find base operations file
  my $base_ops_yml = '';
  my $genesis_root = $ENV{GENESIS_ROOT};
  my $name = $self->env->lookup('params.name', 'generic');

  if (-f "$genesis_root/ops/base.yml") {
    $base_ops_yml = "ops/base.yml";
  } elsif ($name && -f "$genesis_root/ops/$name.yml") {
    $base_ops_yml = "ops/$name.yml";
  } else {
    bail("#R{[ERROR]} Missing base operations file in /ops/ - expecting either base.yml or $name.yml.");
  }

  push @manifest, "base.yml", "$genesis_root/$base_ops_yml";

  # Add jobs ops files
  my $job_ops_files = $self->determine_jobs();
  if ($job_ops_files) {
    push @manifest, @$job_ops_files;
  }

  # Add feature-specific ops files
  my $abort = 0;
  for my $feature ($self->features) {
    if (-f "$genesis_root/ops/$feature.yml") {
      push @manifest, "$genesis_root/ops/$feature.yml";
    } else {
      $abort = 1;
      info("#R{[ERROR]} The #c{%s} feature is invalid. See the ops directory for list of valid features.", $feature);
    }
  }

  if ($abort) {
    bail("#R{Cannot continue} - fix your #C{%s.yml} file to resolve these issues.", $env->name);
  }

  return \@manifest;
}

sub determine_jobs {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');
  my $release_info = $self->detect_release_info();

  if ($release_info && $release_info->{jobs}) {
    # Add jobs based on release info
    my @job_ops_files = ();
    foreach my $job (@{$release_info->{jobs}}) {
      if (-f "ops/jobs/$job.yml") {
        push @job_ops_files, "ops/jobs/$job.yml";
      }
    }
    return \@job_ops_files;
  }
  return [];
}

1;
