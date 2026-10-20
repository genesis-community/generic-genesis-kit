#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::New::Generic v1.1.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook);

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0');
  return $obj;
}

sub perform {
  my ($self) = @_;

  my $file_content = "---\n";
  $file_content .= "kit:\n";
  $file_content .= "  name:     $ENV{GENESIS_KIT_NAME}\n";
  $file_content .= "  version:  $ENV{GENESIS_KIT_VERSION}\n";
  $file_content .= "  features: []\n";
  $file_content .= "\n";
  $file_content .= $self->env->genesis_config_block;
  $file_content .= "params: {}\n";

  $self->env->write_manifest($file_content);

  return $self->done();
}

1;
