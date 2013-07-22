package Nagios::Quicky::Command;
use 5.010;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Parallel::ForkManager;
our $VERSION = '0.01';

use base qw( Nagios::Quicky );

our $debug = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;

sub exec {
  my ($self, $host) = @_;

  no strict 'refs';
  my $check_ref = $self->cfg_params->{service}->{$host};
  my $ip        = $self->cfg_params->{host}->{$host};

  if (! defined $check_ref or ! defined $ip) {
    croak "*** host params is not found";
  }

  my $define_command = $self->cfg_params->{command};
  my $resource       = $self->resource_params;

  for my $check ( @$check_ref ) {
    my $command     = $check->{command};
    my $description = $check->{description};

    my @args = split /\!/, $command;

    my $service_name = shift @args;
    my $exec_command = $define_command->{$service_name};
    $exec_command =~ s/\$HOSTADDRESS\$/$ip/;

    for my $w (keys %$resource) {
      next if not exists $resource->{$w};
      $exec_command =~ s/\Q${w}\E/$resource->{$w}/g;
    }

    for my $arg ( @args ) {
      $exec_command =~ s/\$ARG\d+\$/$arg/;
    }

    print $exec_command, "\n";

  }

}

1;
__END__

=head1 NAME

Nagios::Quicky::Command - exec monitoring commands

=head1 SYNOPSIS

  use Nagios::Quicky::Command;

=head1 DESCRIPTION

Nagios::Quicky::Command is check service actually

=head1 AUTHOR

shin5ok E<lt>shin5ok@55mp.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
