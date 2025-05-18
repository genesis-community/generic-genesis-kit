#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::PostDeploy::Generic v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::PostDeploy);

use Genesis qw/info/;

sub init {
  my ($class, %ops) = @_;
  my $self = $class->SUPER::init(%ops);
  $self->check_minimum_genesis_version('3.1.0-rc.20');
  return $self;
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;
  my $genesis_type = $ENV{GENESIS_TYPE} || 'generic';

  # Base class has deploy_successful method to check if GENESIS_DEPLOY_RC == 0
  if ($self->deploy_successful) {
    # Get the data passed from pre-deploy if any
    my $data_file = $ENV{GENESIS_PREDEPLOY_DATAFILE} || '';
    my $data = '';
    if ($data_file && -f $data_file) {
      open my $fh, "<", $data_file or warn("Could not open $data_file for reading: $!");
      $data = do { local $/; <$fh> };
      close $fh;
    }

    info(
      "\n#M{%s} %s deployed!\n".
      "\nFor details about the deployment, run\n".
      "\t#G{%s info}\n",
      $env->name, $genesis_type, $env->get_call_path_with_env
    );

    # Display any available addon commands
    my $has_addons = 0;
    my $addons_dir = "$ENV{GENESIS_ROOT}/addons";
    if (-d $addons_dir) {
      my @addons = glob("$addons_dir/*");
      if (@addons) {
        $has_addons = 1;
        info("Available addons for this deployment:\n");
        foreach my $addon (@addons) {
          my $addon_name = $addon;
          $addon_name =~ s{.*/}{};
          info("  #G{%s do -- %s}", $env->get_call_path_with_env, $addon_name);
        }
        info("\n");
      }
    }

    # If there are no addons, we'll suggest creating some
    if (!$has_addons) {
      info(
        "No addons available for this deployment. You can create custom addons by adding\n".
        "executable scripts to the #C{%s/addons/} directory.\n",
        $ENV{GENESIS_ROOT}
      );
    }

    # Show the post-deploy health of the deployment
    $self->monitor_deployment_health();

  } else {
    info("\n#R{Deployment failed!}\n");
  }

  return $self->done(1);
}

# In post-deploy.pm
sub monitor_deployment_health {
  my ($self) = @_;
  if (!$self->deploy_successful) {
    return;
  }

  my $name = $self->env->lookup('params.name', 'generic');
  my $deployment_name = $self->env->deployment_name;

  # Check deployment health
  my ($out, $rc) = run('bosh -d %s instances --json', $deployment_name);
  if ($rc == 0) {
    my $instances = decode_json($out);
    my $total = 0;
    my $healthy = 0;

    foreach my $instance (@{$instances->{Tables}[0]{Rows}}) {
      $total++;
      $healthy++ if $instance->{process_state} eq 'running';
    }

    my $health_percentage = $total > 0 ? int(($healthy / $total) * 100) : 0;
    $self->env->notify("Deployment health: %d%% (%d/%d instances running)",
                       $health_percentage, $healthy, $total);

    if ($health_percentage < 100) {
      $self->env->notify(warning => "Not all instances are healthy. Run 'bosh -d %s instances' for details.",
                         $deployment_name);
    }
  }
}

1;
