#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::New::Generic v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

use Genesis qw/run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub perform {
  my ($self) = @_;

  # Create the environment file
  my $env_file = "$ENV{GENESIS_ROOT}/$ENV{GENESIS_ENVIRONMENT}.yml";

  open my $fh, ">", $env_file or bail("Could not open $env_file for writing: $!");

  print $fh "---\n";
  print $fh "kit:\n";
  print $fh "  name:     $ENV{GENESIS_KIT_NAME}\n";
  print $fh "  version:  $ENV{GENESIS_KIT_VERSION}\n";
  print $fh "  features: []\n";

  # Generate and add the genesis_config_block
  my ($out, $rc) = run('genesis_config_block');
  bail("Failed to run genesis_config_block: $out") if $rc != 0;
  print $fh $out;

  print $fh "params: {}\n";
  print $fh "  name: $ENV{GENESIS_RELEASE_NAME}\n";

  close $fh;

  # Offer environment editor
  run({ interactive => 1 }, 'offer_environment_editor');

  return $self->done();
}

# TODO: Create a templates directory with common patterns for different types of deployments:
sub setup_templates {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');
  my $type = $self->determine_release_type($name);

  # Copy appropriate templates based on release type
  my $template_dir = "templates/$type";
  if (-d $template_dir) {
    run('cp -r %s/* %s/', $template_dir, $ENV{GENESIS_ROOT});
    $self->env->notify("Copied templates for %s-type release", $type);
  }
}

sub determine_release_type {
  my ($self, $name) = @_;

  # Determine template type based on release name patterns
  if ($name =~ /db|sql|mysql|postgres/) {
    return 'database';
  } elsif ($name =~ /broker|service/) {
    return 'service-broker';
  } elsif ($name =~ /log|metric|monitor/) {
    return 'monitoring';
  }

  return 'default';
}

1;

