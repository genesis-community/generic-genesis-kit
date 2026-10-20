#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Generic::Usage v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/info run/;
use File::Basename qw/basename/;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub cmd_details {
  return
  "Shows the help text of an addon in the deployment repo's addons/ directory.\n".
  "Usage: usage <addon-name>\n".
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
    $self->_list_addons;
    return $self->done(1);
  }

  # Check if the addon exists
  my $addon_path = "$genesis_root/addons/$addon_name";
  if (!-f $addon_path) {
    $env->notify("Unrecognized addon '$addon_name'.");
    $self->_list_addons;
    return $self->done(0);
  }

  # Get help text from the addon
  my ($help_text, $rc) = run({ stderr => '/dev/null' },
    '"$1/addons/$2" help', $genesis_root, $addon_name);

  if ($rc == 0 && $help_text) {
    $env->notify("Help for addon '#Gu{%s}':", $addon_name);
    $env->notify("");
    info("%s", $help_text);
  } else {
    $env->notify("No help text available for addon '#Gu{%s}'.", $addon_name);
  }

  return $self->done();
}

# Lists the deployment repo's addons/ scripts with each one's help text.
sub _list_addons {
  my ($self) = @_;
  my $dir = "$ENV{GENESIS_ROOT}/addons";
  my @addons = -d $dir
    ? sort grep {-f "$dir/$_" && -x "$dir/$_"} map {basename($_)} glob("\Q$dir\E/*")
    : ();
  unless (@addons) {
    info(
      "\nThere are no addons in this deployment repo's #C{addons/} directory.  " .
      "To provide one, add an executable script there that answers #y{help} " .
      "with its usage text and #y{run} with its behaviour.\n"
    );
    return;
  }
  info("\nThe following addons are defined in this deployment repo:");
  for my $addon (@addons) {
    my ($help) = run({stderr => '/dev/null'}, '"$1/addons/$2" help', $ENV{GENESIS_ROOT}, $addon);
    $help //= '';
    $help =~ s/^/    /mg;
    info("\n  #Gu{%s}\n%s", $addon, $help);
  }
  info("");
}

1;
