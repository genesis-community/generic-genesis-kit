#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Generic::Help v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run/;
use File::Basename qw/basename/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Provides help information for an addon.\n".
  "Usage: help <addon-name>\n".
  "If no addon name is provided, lists all available addons.";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $genesis_root = $ENV{GENESIS_ROOT};

  # Get the addon script name from the first argument
  my $addon_name = $self->{args}[0] || '';
  if (!$addon_name) {
    # No addon specified, show the list of available addons
    $env->run_hook('addon', script => 'list');
    return $self->done(1);
  }

  # Check if the addon exists
  my $addon_path = "$genesis_root/addons/$addon_name";
  if (!-f $addon_path) {
    $env->notify("Unrecognized addon '$addon_name'.");
    $env->run_hook('addon', script => 'list');
    return $self->done(0);
  }

  # Get help text from the addon
  my ($help_text, $rc) = run({ stderr => '/dev/null' },
    '$1/addons/$2 help', $genesis_root, $addon_name);

  if ($rc == 0 && $help_text) {
    $env->notify("Help for addon '#Gu{%s}':", $addon_name);
    $env->notify("");
    info("%s", $help_text);
  } else {
    $env->notify("No help text available for addon '#Gu{%s}'.", $addon_name);
  }

  return $self->done(1);
}

1;
