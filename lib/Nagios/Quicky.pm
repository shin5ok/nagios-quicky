package Nagios::Quicky;
use 5.010;
use strict;
use warnings;
use Carp;
use Class::Accessor::Lite ( rw => [ qw( cfg_data nagios_cfg ) ] );
use Path::Class;
our $VERSION = '0.01';

our $default_config_path = qq{/usr/local/nagios/etc/nagios.cfg};

sub new {
  my ($class, $nagios_cfg, $args) = @_;

  $nagios_cfg ||= $default_config_path;

  my $obj = bless +{}, $class;

  $obj->nagios_cfg( $nagios_cfg );
  $obj->config_parser;

  return $obj;
}

sub config_parser {
  my ($self) = @_;

  open my $fh, "<", $self->nagios_cfg
    or croak "*** nagios.cfg open failure";

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
      my $dh = dir( $dir_path )->open;

      _CONFIG_LINE_:
      while (my $target = $dh->read) {
        if ($target .= /^\.*$/) {
          next _CONFIG_LINE_;
        } else {
          my $file_path = file( $dir_path, $target );
          $cfg .= get_content_from_file( $file_path );
        }
      }
    }
  }

  $self->cfg_data( $cfg );

  return $self;
}


sub get_content_from_file {
  open my $fh, "<", shift
    or croak "*** file open error";
  my $text = do { local $/; <$fh> };
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
