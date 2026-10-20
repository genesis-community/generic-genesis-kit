#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/bail load_yaml_file new_enough semver/;

# bpm releases older than this do not compile on the resolute stemcell,
# because their tini package needs an older CMake than resolute ships.
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

  my ($manifest, $rc, $err) = load_yaml_file($manifest_file);
  bail(
    "Could not read the deployment manifest %s: %s", $manifest_file, $err || 'not a YAML map'
  ) unless $rc == 0 && ref($manifest) eq 'HASH';

  $self->{vars} = $self->_load_vars;
  $self->_check_resolute($manifest);

  return $self->done(1);
}

# BOSH fills ((name)) placeholders at deploy time, from the variables file
# Genesis passes along, so we resolve them the same way before checking.
sub _load_vars {
  my ($self) = @_;
  my $vars_file = $ENV{GENESIS_BOSHVARS_FILE} || '';
  return {} unless $vars_file && -f $vars_file;
  my ($vars, $rc, $err) = load_yaml_file($vars_file);
  bail(
    "Could not read the BOSH variables file %s: %s", $vars_file, $err || 'not a YAML map'
  ) unless $rc == 0 && ref($vars) eq 'HASH';
  return $vars;
}

sub _value {
  my ($self, $value, $what) = @_;
  return $value unless defined($value) && !ref($value);
  return $value unless $value =~ /\(\(/;
  (my $resolved = $value) =~ s{\(\(\s*([^()\s]+)\s*\)\)}{
    my $name = $1;
    bail(
      "The manifest sets %s to #R{((%s))}, which no BOSH variable in the " .
      "environment resolves, so the resolute checks cannot tell what it " .
      "deploys.  Set it in the environment file instead.", $what, $name
    ) unless defined($self->{vars}{$name}) && !ref($self->{vars}{$name});
    $self->{vars}{$name};
  }ge;
  return $resolved;
}

sub _list {
  my ($self, $manifest, $key) = @_;
  my $list = $manifest->{$key} // [];
  bail(
    "The manifest's #c{%s} key must be a list, not %s.", $key, ref($list) || 'a string'
  ) unless ref($list) eq 'ARRAY';
  return grep {ref($_) eq 'HASH'} @$list;
}

# The deployment repo writes the manifest, so the kit cannot pin bpm itself.
# Instead we refuse a resolute deploy that would ship a bpm too old to run
# there, and one whose own stemcells block undoes the resolute feature.
sub _check_resolute {
  my ($self, $manifest) = @_;

  my @stemcells = map {{
    alias => $self->_value($_->{alias}, 'a stemcell alias') // '<none>',
    os    => $self->_value($_->{os},    'a stemcell os'),
    name  => $self->_value($_->{name},  'a stemcell name'),
  }} $self->_list($manifest, 'stemcells');
  my $is_resolute = sub {
    my ($s) = @_;
    return defined($s->{os}) ? $s->{os} eq 'ubuntu-resolute'
                             : ($s->{name} // '') =~ /ubuntu-resolute/;
  };
  my @resolute = grep {$is_resolute->($_)} @stemcells;

  if ($self->want_feature('resolute')) {
    my @other = grep {!$is_resolute->($_)} @stemcells;
    bail(
      "The #c{resolute} feature is enabled, but the manifest's stemcells " .
      "block also names %s.  Remove those stemcells, or their os and name " .
      "keys, from your ops files so that the feature sets the stemcell os.",
      join(', ', map {
        defined($_->{os})
          ? sprintf("os #R{%s} (alias %s)", $_->{os}, $_->{alias})
          : sprintf("name #R{%s} (alias %s)", $_->{name} // '<none>', $_->{alias})
      } @other)
    ) if @other;
  }

  return unless @resolute;

  for my $release ($self->_list($manifest, 'releases')) {
    next unless ($self->_value($release->{name}, 'a release name') // '') eq 'bpm';
    my $version = $self->_value($release->{version}, 'the bpm release version');
    bail(
      "The manifest deploys bpm without a version on a resolute stemcell.  " .
      "Pin bpm to %s or newer in your ops files.", $RESOLUTE_MIN_BPM
    ) unless defined($version) && $version ne '';
    bail(
      "The manifest deploys bpm #R{latest} on a resolute stemcell.  Pin bpm " .
      "to %s or newer in your ops files, so the deploy cannot pick up an " .
      "older upload.", $RESOLUTE_MIN_BPM
    ) if $version eq 'latest';
    bail(
      "The manifest deploys bpm #R{%s} on a resolute stemcell, which needs " .
      "bpm %s or newer.  Raise the bpm release in your ops files.",
      $version, $RESOLUTE_MIN_BPM
    ) unless semver($version) && new_enough($version, $RESOLUTE_MIN_BPM);
  }
}

1;
