#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PreDeploy::Generic v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/info run bail/;

sub init {
  my ($class, %ops) = @_;
  my $obj = $class->SUPER::init(%ops);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $genesis_type = $ENV{GENESIS_TYPE} || 'generic';

  # Load manifest data
  my $manifest_file = $ENV{GENESIS_MANIFEST_FILE} || '';
  my $vars_file = $ENV{GENESIS_BOSHVARS_FILE} || '';

  if (!$manifest_file || !-f $manifest_file) {
    bail("Manifest file '%s' not found or not specified", $manifest_file);
  }

  $env->notify("running pre-deploy checks for %s environment...", $genesis_type);

  $self->detect_release_info();

  $self->ensure_release_available();

  # Here we would add any specific pre-deployment logic
  # For now this is a placeholder for any pre-deployment tasks

  # Create an empty data file for post-deploy to use
  my $data_file = $env->workpath("data");
  open my $fh, ">", $data_file or bail("Could not open $data_file for writing: $!");
  # You can add data here if needed in post-deploy
  close $fh;

  return (1, ""); # Return success with no data
}

sub detect_release_info {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');

  # Check for release information in bosh.io
  my ($out, $rc) = run('curl -s https://bosh.io/api/v1/releases/' . $name);
  if ($rc == 0 && $out) {
    my $release_info = decode_json($out);
    # Suggest latest version if not specified
    if (!$self->env->lookup('params.version')) {
      info("Latest version of %s release is %s", $name, $release_info->{version});
      # Optionally prompt for version selection
    }
    return $release_info;
  }
  return undef;
}

sub ensure_release_available {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');
  my $version = $self->env->lookup('params.version');
  my $sha1 = $self->env->lookup('params.sha1');

  if (!$version) {
    $self->env->notify(error => "No version specified for %s release", $name);
    return 0;
  }

  # Check if release exists in BOSH director
  my ($out, $rc) = run('bosh releases --json');
  if ($rc == 0) {
    my $releases = decode_json($out);
    foreach my $release (@{$releases->{Tables}[0]{Rows}}) {
      if ($release->{name} eq $name && $release->{version} eq $version) {
        return 1; # Release already available
      }
    }
  }

  # Download release if not available
  my $url = "https://bosh.io/d/github.com/$name/$name-release?v=$version";
  $self->env->notify("Downloading %s release v%s...", $name, $version);
  run('curl -L -o /tmp/%s-%s.tgz %s', $name, $version, $url);

  # Verify checksum if provided
  if ($sha1) {
    my ($sum, $rc) = run('sha1sum /tmp/%s-%s.tgz | cut -d " " -f 1', $name, $version);
    if ($sum ne $sha1) {
      $self->env->notify(error => "SHA1 mismatch for downloaded release");
      return 0;
    }
  }

  # Upload to BOSH
  run('bosh upload-release /tmp/%s-%s.tgz', $name, $version);
  return 1;
}

# This is an idea for improving the generic kit, the ops files
# named below are just examples that we can discuss
sub generate_ops_files {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');
  my $params = $self->env->lookup('params', {});

  # Generate standard ops files if they don't exist
  my @standard_ops = ('scaling', 'ha', 'tls', 'networking');
  foreach my $op (@standard_ops) {
    my $ops_file = "ops/$op.yml";
    if (!-f $ops_file) {
      my $template = slurp("templates/$op.yml.erb");
      # Replace placeholders with values from params
      $template =~ s/\{\{name\}\}/$name/g;
      # Add more replacements as needed

      mkfile_or_fail($ops_file, $template);
      $self->env->notify("Generated ops file: %s", $ops_file);
    }
  }
}

1;
