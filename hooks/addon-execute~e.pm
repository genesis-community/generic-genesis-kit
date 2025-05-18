#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Generic::Execute v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Executes a custom addon from the 'addons/' directory.\n".
  "Usage: do <addon-name> [arguments...]\n".
  "This passes through all arguments to the addon script.";
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
    return $self->done(0);
  }

  # Check if the addon exists and is executable
  my $addon_path = "$genesis_root/addons/$addon_name";
  if (!-f $addon_path) {
    $env->notify("Unrecognized addon '$addon_name'.");
    $env->run_hook('addon', script => 'list');
    return $self->done(0);
  }

  if (!-x $addon_path) {
    $env->notify("Addon '$addon_name' exists but is not executable.");
    return $self->done(0);
  }

  # Execute the addon script with 'run' command and pass remaining arguments
  my @addon_args = @{$self->{args}};
  shift @addon_args; # Remove the addon name

  my $cmd = "(cd \"$genesis_root\" && \"addons/$addon_name\" run " . join(' ', map { "'$_'" } @addon_args) . ")";
  my ($out, $rc, $err) = run({ interactive => 1 }, $cmd);

  if ($rc != 0) {
    $env->notify(error => "Addon '$addon_name' failed with exit code $rc.");
    return $self->done(0);
  }

  return $self->done(1);
}

1;
