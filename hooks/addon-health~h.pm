#!/usr/bin/env perl
# vim: set ts=2 sw=2 sts=2 foldmethod=marker
package Genesis::Hook::Addon::Generic::Health v1.0.0;

use strict;
use warnings;
use v5.20; # Genesis min perl version is 5.20

# Only needed for development
BEGIN {push @INC, $ENV{GENESIS_LIB} ? $ENV{GENESIS_LIB} : $ENV{HOME}.'/.genesis/lib'}
use parent qw(Genesis::Hook::Addon);

use Genesis qw/bail info run/;
use JSON::PP;

sub init {
  my $class = shift;
  my $obj = $class->SUPER::init(@_);
  $obj->check_minimum_genesis_version('3.1.0-rc.20');
  return $obj;
}

sub cmd_details {
  return
  "Monitors the health of the deployment.\n".
  "This command checks all instances and processes in the deployment and reports their status.\n".
  "Supports the following options:\n".
  "[[  #y{--verbose, -v}         >>Show detailed health information for each instance\n".
  "[[  #y{--watch, -w}           >>Watch deployment health continuously (polls every 5 seconds)\n".
  "[[  #y{--help, -h}            >>Show this help information";
}

sub perform {
  my ($self) = @_;
  my $env = $self->env;

  # Parse options
  my %options = $self->parse_options([
    'verbose|v',
    'watch|w',
    'help|h',
  ]);

  # Display help if requested
  if ($options{help}) {
    $self->help();
    return $self->done(1);
  }

  # Get the release name from params
  my $name = $env->lookup('params.name', 'generic');
  my $deployment_name = $env->deployment_name;

  # Check deployment state
  my $deployment_state = $env->deployment_state();
  if ($deployment_state ne 'deployed') {
    $env->notify(error => "Deployment %s is not in deployed state (current state: %s)",
      $deployment_name, $deployment_state);
    return $self->done(0);
  }

  # Function to check health - wrapped in a sub for watch mode
  my $check_health = sub {
    # Check if BOSH director is accessible
    my ($director_check, $rc) = run('bosh environment');
    if ($rc != 0) {
      $env->notify(error => "Cannot connect to BOSH director. Please make sure you're logged in.");
      return 0;
    }

    # Get deployment instances
    $env->notify("Checking health of %s deployment (%s)...", $name, $deployment_name);
    my ($out, $rc) = run('bosh -d %s instances --details --json', $deployment_name);
    if ($rc != 0) {
      $env->notify(error => "Failed to get deployment instances. Error: %s", $out);
      return 0;
    }

    # Parse JSON output
    my $instances_data;
    eval {
      $instances_data = decode_json($out);
    };
    if ($@) {
      $env->notify(error => "Failed to parse BOSH output: %s", $@);
      return 0;
    }

    # Process instance data
    my $table = $instances_data->{Tables}[0];
    my @rows = @{$table->{Rows} || []};
    my $total = scalar @rows;
    my $healthy = 0;
    my $failing = 0;
    my @failing_instances;

    foreach my $instance (@rows) {
      my $is_healthy = ($instance->{process_state} eq 'running' &&
                        $instance->{active} eq 'true' &&
                        $instance->{state} eq 'started');

      if ($is_healthy) {
        $healthy++;
      } else {
        $failing++;
        push @failing_instances, {
          name => $instance->{instance},
          job => $instance->{job},
          process_state => $instance->{process_state},
          state => $instance->{state},
          active => $instance->{active},
          vm_type => $instance->{vm_type},
          ips => $instance->{ips},
        };
      }
    }

    # Calculate health percentage
    my $health_percentage = $total > 0 ? int(($healthy / $total) * 100) : 0;

    # Display summary
    info("\nDeployment: #C{%s}", $deployment_name);
    info("Total instances: #C{%d}", $total);
    info(
      "Health status: #%s{%d%%} (%d healthy, %d unhealthy)\n",
      $health_percentage == 100 ? "G" : $health_percentage >= 80 ? "Y" : "R",
      $health_percentage, $healthy, $failing
    );

    # Display failing instances if any or if verbose mode
    if ($failing > 0) {
      info("#R{Unhealthy instances:}");
      foreach my $instance (@failing_instances) {
        info("\t#C{%s/%s}: #R{%s} (state: %s, active: %s, IP: %s\n)",
          $instance->{job}, $instance->{name},
          $instance->{process_state}, $instance->{state},
          $instance->{active}, $instance->{ips});
      }
      info("\n");
    }

    # Show detailed instance info in verbose mode
    if ($options{verbose} && $total > 0) {
      info("#Y{Instance details:}");
      foreach my $instance (@rows) {
        my $health_indicator = (
          $instance->{process_state} eq 'running' &&
          $instance->{active} eq 'true' &&
          $instance->{state} eq 'started'
        ) ? "#G{✓}" : "#R{✗}";

        info(
          "\t%s #C{%s/%s} [%s] - #Y{%s} (%s)\n",
          $health_indicator,
          $instance->{job},
          $instance->{name},
          $instance->{vm_type},
          $instance->{ips},
          $instance->{az}
        );
      }
    }

    # Provide recommendations if not fully healthy
    if ($health_percentage < 100) {
      info("\n#Y{Recommendations:}");
      info("\tRun for detailed troubleshooting:");
      info("\t\t#G{bosh -d %s instances --ps}", $deployment_name);
      info("\t\t#G{bosh -d %s ssh <instance>}", $deployment_name);
      info("\t\t#G{bosh -d %s logs <instance>}\n", $deployment_name);
    }

    return $health_percentage == 100;
  };

  # Watch mode - continuously check health
  if ($options{watch}) {
    $env->notify("Watching deployment health (Press Ctrl+C to stop)...");
    my $counter = 0;

    # Use eval to catch Ctrl+C
    eval {
      local $SIG{INT} = sub { die "Interrupted\n" };
      while (1) {
        info("\n#B{Health check #%d} - %s", ++$counter, scalar localtime);
        $check_health->();
        sleep 5;
      }
    };
    if ($@ && $@ ne "Interrupted\n") {
      $env->notify(error => "Error in watch mode: %s", $@);
    } else {
      $env->notify("Health monitoring stopped.");
    }
  } else {
    # Run health check once
    $check_health->();
  }

  return $self->done();
}

1;
