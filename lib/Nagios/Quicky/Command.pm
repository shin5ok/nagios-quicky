package Nagios::Quicky::Command;
use 5.010;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Parallel::ForkManager;
use IPC::Cmd qw( run );
use File::Basename;
use DBI;
use MongoDB;
our $VERSION = '0.01';

use base qw( Nagios::Quicky );

our $debug   = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;
our $db_path = "/tmp/." . basename __FILE__;
our $default_procs = 8;

our $mongod          = q{127.0.0.1};
our $mongod_port     = 27017;
our $mongo_dbname    = q{nagios};
our $mongo_collname  = q{quicky};
our $command_timeout = 30;

sub exec {
  my ($self, $host, $option) = @_;

  no strict 'refs';
  my $check_ref = $self->cfg_params->{service}->{$host};
  my $ip        = $self->cfg_params->{host}->{$host};

  if (! defined $check_ref or ! defined $ip) {
    croak "*** host params is not found";
  }

  my $define_command = $self->cfg_params->{command};
  my $resource       = $self->resource_params;

  my %exec_command_db;
  for my $check ( @$check_ref ) {
    my $command     = $check->{command};
    my $description = $check->{description};

    my @args = split /\!/, $command;

    my $service_name = shift @args;
    my $exec_command = $define_command->{$service_name};
    $exec_command =~ s/\$HOSTADDRESS\$/$ip/;

    for my $arg ( @args ) {
      $exec_command =~ s/\$ARG\d+\$/$arg/;
    }

    for my $w (keys %$resource) {
      next if not exists $resource->{$w};
      $exec_command =~ s/\Q${w}\E/$resource->{$w}/g;
    }

    $exec_command_db{$description} = $exec_command;


  }

  my $procs = $option->{procs} // $default_procs;
  $self->parallel_command({
                            commands    => \%exec_command_db,
                            procs       => $procs,
                          } );

}

sub parallel_command {
  my $self = shift;
  my $args = shift;

  my $pfork = Parallel::ForkManager->new( $args->{procs} );

  chomp( my $check_id = qx/uuidgen/ );
  $check_id //= rand() . rand() . rand();

  my $command_ref = $args->{commands};
  for my $description ( keys %$command_ref ) {
    $pfork->start and next;
    my $command = $command_ref->{$description};
    _command( $command, $description, $check_id );
    $pfork->finish;
  }

  $pfork->wait_all_children;

  my $coll = _connect_db();
  my @results;
  for my $v ( $coll->find( { check_id => $check_id } )->all ) {
    push @results, +{
                     command     => $v->{command},
                     stderr      => $v->{stderr},
                     stdout      => $v->{stdout},
                     id          => $v->{id},
                     description => $v->{description},
                     success     => $v->{success},
                   };

  }

  warn Dumper \@results if $debug;
  return \@results;

}


sub _command {
  my $command     = shift;
  my $description = shift;
  my $check_id    = shift;

  my @results = run( command => $command, { timeout => $command_timeout } );
  my $coll = _connect_db();
  $coll->insert( {
                   check_id    => $check_id,
                   command     => $command,
                   description => $description,
                   stdout      => $results[3],
                   stderr      => $results[4],
                   success     => $results[0],
                 });
}

sub _connect_db {
  my $client     = MongoDB::MongoClient->new(host => $mongod, port => $mongod_port);
  my $database   = $client->get_database( $mongo_dbname );
  my $collection = $database->get_collection( $mongo_collname );
  return $collection;
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
