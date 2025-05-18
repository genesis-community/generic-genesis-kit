#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 et:
package Genesis::Hook::Info::Generic v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis supports min perl v5.20.

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}

# Parent class inheritance
use parent qw(Genesis::Hook);

# Import required functions
use Genesis qw/bail info run/;

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

  # Get basic deployment info
  my $deployment_state = $env->deployment_state();

  # Display header
  info("\n#B{%s Deployment Information}", $genesis_type);
  info("\nDeployment State: #%s{%s}",
    $deployment_state eq 'deployed' ? 'G' :
    $deployment_state eq 'undeployed' ? 'R' : 'Y',
    $deployment_state);

  # Display details from exodus data if deployed
  if ($deployment_state eq 'deployed') {
    my $exodus = $env->exodus_lookup('.');

    # Display generic deployment info
    info("\nDeployment Info:");
    info("  Genesis Kit: #M{%s} v%s",
      $exodus->{kit_name} || $genesis_type,
      $exodus->{kit_version} || 'unknown');
    info("  Deployed: %s", $exodus->{dated} || 'unknown');
    info("  Deployer: %s", $exodus->{deployer} || 'unknown');

    # Display feature information
    my $features = $exodus->{features} || '';
    if ($features) {
      info("\nActive Features:");
      for my $feature (split(/,/, $features)) {
        info("  - #C{%s}", $feature);
      }
    }

    # Display IPs if available
    my $static_ip = $env->lookup('params.static_ip');
    if ($static_ip) {
      info("\nEndpoint Information:");
      info("  IP Address: #C{%s}", $static_ip);
    }

    # BOSH Info
    if (my $bosh_info = $exodus->{bosh}) {
      info("\nBOSH Information:");
      info("  BOSH Director: #C{%s}", $bosh_info);
    }

    # Determine if addons exist and display info
    my $addons_dir = "$ENV{GENESIS_ROOT}/addons";
    if (-d $addons_dir) {
      my @addons = glob("$addons_dir/*");
      if (@addons) {
        info("\nAvailable Addons:");
        foreach my $addon (@addons) {
          my $addon_name = $addon;
          $addon_name =~ s{.*/}{};
          info("  #G{%s do -- %s}", $env->get_call_path_with_env, $addon_name);
        }
      }
    }
  } else {
    info("\nNo deployment information available.\n");
  }

  $self->generate_documentation();

  return $self->done(1);
}

sub generate_documentation {
  my ($self) = @_;
  my $name = $self->env->lookup('params.name', 'generic');
  my $doc_dir = "docs";

  # Create docs directory if it doesn't exist
  mkdir_or_fail($doc_dir) unless -d $doc_dir;

  # Generate README
  my $readme = "$doc_dir/README.md";
  open my $fh, ">", $readme or bail("Could not open $readme for writing: $!");

  print $fh "# $name Deployment\n\n";
  print $fh "## Overview\n\n";
  print $fh "This is a deployment of the $name BOSH release using the Genesis Generic Kit.\n\n";

  # Add parameters documentation
  print $fh "## Parameters\n\n";
  my $params = $self->env->lookup('params', {});
  foreach my $key (sort keys %$params) {
    print $fh "- `$key`: " . ($params->{$key} || "Not set") . "\n";
  }

  # Add features documentation
  print $fh "\n## Features\n\n";
  foreach my $feature ($self->env->features) {
    print $fh "- `$feature`\n";
  }

  close $fh;

  $self->env->notify("Generated documentation at %s", $readme);
  return 1;
}


1;
