#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/bail load_yaml_file new_enough/;

# bpm releases older than this cannot start jobs on the cgroup v2 hosts that
# the resolute stemcell boots.
my $RESOLUTE_MIN_BPM = '1.4.41';

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  my $manifest_file = $ENV{GENESIS_MANIFEST_FILE} || '';
  bail(
    "Manifest file '%s' not found or not specified", $manifest_file
  ) unless $manifest_file && -f $manifest_file;

  $env->notify("running pre-deploy checks for %s environment...", $env->type || 'generic');

  my $manifest = load_yaml_file($manifest_file);
  $self->_check_resolute($manifest);

  return $self->done(1);
}

# The deployment repo writes the manifest, so the kit cannot pin bpm itself.
# Instead we refuse a resolute deploy that would ship a bpm too old to run
# there, and one whose own stemcells block undoes the resolute feature.
sub _check_resolute {
  my ($self, $manifest) = @_;

  my @stemcells = @{$manifest->{stemcells} || []};
  my @resolute = grep {($_->{os} // '') eq 'ubuntu-resolute'} @stemcells;

  if ($self->want_feature('resolute')) {
    my @other = grep {($_->{os} // '') ne 'ubuntu-resolute'} @stemcells;
    bail(
      "The #c{resolute} feature is enabled, but the manifest's stemcells " .
      "block also names %s.  Remove those stemcells, or their os keys, from " .
      "your ops files so that the feature sets the stemcell os.",
      join(', ', map {sprintf("#R{%s} (alias %s)", $_->{os} // '<none>', $_->{alias} // '<none>')} @other)
    ) if @other;
  }

  return unless @resolute;

  for my $release (@{$manifest->{releases} || []}) {
    next unless ($release->{name} // '') eq 'bpm';
    my $version = $release->{version} // '';
    bail(
      "The manifest deploys bpm #R{latest} on a resolute stemcell.  Pin bpm " .
      "to %s or newer in your ops files, so the deploy cannot pick up an " .
      "older upload.", $RESOLUTE_MIN_BPM
    ) if $version eq 'latest';

    (my $base_version = $version) =~ s/[+-].*$//;
    bail(
      "The manifest deploys bpm #R{%s} on a resolute stemcell, which needs " .
      "bpm %s or newer.  Raise the bpm release in your ops files.",
      $version, $RESOLUTE_MIN_BPM
    ) unless $base_version =~ /^\d+(\.\d+)*$/ && new_enough($base_version, $RESOLUTE_MIN_BPM);
  }
}

1;
