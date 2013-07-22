package Nagios::Quicky;
use 5.010;
use strict;
use warnings;
use Carp;
use Class::Accessor::Lite ( rw => [ qw( cfg_data nagios_cfg cfg_params resource_params ) ] );
use Path::Class;
use Data::Dumper;
use File::Find;
our $VERSION = '0.01';

our $default_config_path = qq{/usr/local/nagios/etc/nagios.cfg};
our $debug = exists $ENV{DEBUG} ? $ENV{DEBUG} : 0;

sub new {
  my ($class, $nagios_cfg, $args) = @_;

  $nagios_cfg //= $default_config_path;

  my $obj = bless +{}, $class;

  $obj->nagios_cfg( $nagios_cfg );
  $obj->config_parser;

  return $obj;
}

sub config_parser {
  my ($self) = @_;

  open my $fh, "<", $self->nagios_cfg
    or croak "*** nagios.cfg open failure";

  my %resource = ();

  my $cfg = qq{};
  _CONFIG_FILE_:
  while (my $line = <$fh>) {
    $line =~ /^\s*\#/ and next _CONFIG_FILE_;
    $line =~ /^\s*$/  and next _CONFIG_FILE_;

    $cfg .= "\n";
    # cfg_file=/usr/local/nagios/etc/misccommands.cfg
    # cfg_dir=/usr/local/nagios/etc/servers
    if ($line =~ /^\s*cfg_file \s* \= \s*(\S+)/x) {
      $cfg .= get_content_from_file( $1 );
    }
    elsif ($line =~ /^\s*cfg_dir \s* \= \s*(\S+)/x) {
      my $dir_path = $1;
      find(sub {
                 my $file_path = $File::Find::name;

                 -f $file_path          or return;
                 $file_path =~ /\.cfg$/ or return;
                 my $file = file( $file_path );

                 $cfg .= get_content_from_file( $file->stringify );
               },
               $dir_path);
    }
    elsif ($line =~ /^\s*resource_file \s* \= \s*(\S+)/x) {
      for my $line ( split /\n/, get_content_from_file( $1 ) ) {
        $line =~ /^\s*#/ and next;
        if ($line =~ /^\s*(\$[^\=\s]+)\s*\=\s*(\S+)/) {
          $resource{$1} = $2;
        }
      }
      $self->resource_params( \%resource );
    }
  }

  $self->cfg_data( $cfg );

  $self->convert_data_to_hash;

  return $self;
}


sub convert_data_to_hash {
  my ($self) = @_;

  $self->cfg_data
    or croak "*** no nagios data";

  my @defines =
    $self->cfg_data =~ /^
                           \s* ( define \s+ [^\{\s]+ \s* \{
                              [^\}]+ )
                          \}
                      /xgms;

  # {
  #   command => {
  #                check_pop3 => {
  #                                command_line => q{$USER1$/check_pop -H $HOSTADDRESS$},
  #                              },
  #                check_ssh  => {
  #                                command_line => q{$USER1$/check_ssh -H $HOSTADDRESS$},
  #                              },
  #              },
  #   service => {
  #                testvps01 => [
  #                                {
  #                                  description => 'check_mysql3',
  #                                  command     => q{check_mysql3!3306!$USER10$!$USER10$!$USER16$},
  #                                },
  #                                {
  #                                  description => q{check_ssh},
  #                                  command     => q{check_nrpe!check_hosting_mn_mailq_count},
  #                                },
  #                              ],
  #                testvps02  => [
  #                                {
  #                                  description => 'check_mysql3',
  #                                  command     => q{check_mysql3!3306!$USER10$!$USER10$!$USER16$},
  #                                },
  #                                {
  #                                  description => 'check_mysql8',
  #                                  command     =>  q{check_nrpe!check_hosting_mn_mailq_count},
  #                                },
  #                              ],
  #              },
  #   host => {
  #             testvps01 => q{192.168.241.25},
  #             testvps02 => q{192.168.241.28},
  #           },
  #   resource => {
  #                 '$USER1$' => '/usr/local/nagios/libexec',
  #               },
  # }

  my $hash_ref = +{};
  no strict 'refs';
  my (%host, %service, %command);
  for my $x ( @defines ) {
    my ($define_name, $data) =
      $x =~ / define \s+
                ([^\{\s]+)
                ( [^\}]+ )
           /xms or next;

    if ($define_name eq q{host}) {
      my ($address, $name);
      if ($data =~ /address \s+(\S+)/x) {
        $address = $1;
      }
      if ($data =~ /host_name \s+(\S+)/x) {
        $name = $1;
      }
      if (defined $address and defined $name) {
        $hash_ref->{host}->{$name} = $address;
      }
    }
    elsif ($define_name eq q{service}) {
      my ($name, $description);
      if ($data =~ /host_name \s+(\S+)/x) {
        $name = $1;
        if ($data =~ /service_description \s+ (\S+)/x) {
          $description = $1;
          if ($data =~ /check_command \s+(\S+)/x) {
            my $ref = +{
                         description => $description,
                         command     => $1,
                       };
            push @{$hash_ref->{service}->{$name}}, $ref;
          }
        }
      }
    }
    elsif ($define_name eq q{command}) {
      my $name;
      if ($data =~ /command_name \s+(\S+)/x) {
        $name = $1;
        if ($data =~ /command_line \s+(.+)/x) {
          $hash_ref->{command}->{$name} = $1;
        }
      }
    }
  }

  $self->cfg_params( $hash_ref );
  return $self;
}


sub get_content_from_file {
  my $file = shift;
  open my $fh, "<", $file
    or croak "*** file $file open error";
  my $text = qq{};
  while (my $line = <$fh>) {
    $line =~ /^\s*$/ and next;
    $line =~ /^\s*#/ and next;
    $text .= $line;
  }
  close $fh;
  return $text;
}


1;
__END__

=head1 NAME

Nagios::Quicky -

=head1 SYNOPSIS

  use Nagios::Quicky;

=head1 DESCRIPTION

Nagios::Quicky is

=head1 AUTHOR

shin5ok E<lt>shin5ok@55mp.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
