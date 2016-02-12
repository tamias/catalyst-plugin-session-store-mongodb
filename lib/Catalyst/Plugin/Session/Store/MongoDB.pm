package Catalyst::Plugin::Session::Store::MongoDB;
use strict;
use warnings;

our $VERSION = '0.02';

use Moose;
use namespace::autoclean;

use MongoDB::Connection;
use Data::Dumper;

BEGIN { extends 'Catalyst::Plugin::Session::Store' }

has hostname => (
  isa => 'Str',
  is => 'ro',
  lazy_build => 1,
);

has port => (
  isa => 'Int',
  is => 'ro',
  lazy_build => 1,
);

has dbname => (
  isa => 'Str',
  is => 'ro',
  lazy_build => 1,
);

has collectionname => (
  isa => 'Str',
  is => 'ro',
  lazy_build => 1,
);

has '_collection' => (
  isa => 'MongoDB::Collection',
  is => 'ro',
  lazy_build => 1,
);

has '_connection' => (
  isa => 'MongoDB::Connection',
  is => 'ro',
  lazy_build => 1,
);

has '_db' => (
  isa => 'MongoDB::Database',
  is => 'ro',
  lazy_build => 1,
);

sub _cfg_or_default {
  my ($self, $name, $default) = @_;

  my $cfg = $self->_session_plugin_config;

  return $cfg->{$name} || $default;
}

sub _build_hostname {
  my ($self) = @_;
  return $self->_cfg_or_default('hostname', 'localhost');
}

sub _build_port {
  my ($self) = @_;
  return $self->_cfg_or_default('port', 27017);
}

sub _build_dbname {
  my ($self) = @_;
  return $self->_cfg_or_default('dbname', 'catalyst');
}

sub _build_collectionname {
  my ($self) = @_;
  return $self->_cfg_or_default('collectionname', 'session');
}

sub _build__collection {
  my ($self) = @_;

  return $self->_db->get_collection($self->collectionname);
}

sub _build__connection {
  my ($self) = @_;

  return MongoDB::Connection->new(
    host => $self->hostname,
    port => $self->port,
  );
}

sub _build__db {
  my ($self) = @_;

  return $self->_connection->get_database($self->dbname);
}

sub _serialize {
  my ($self, $data) = @_;

  my $d = Data::Dumper->new([ $data ]);

  return $d->Indent(0)->Purity(1)->Terse(1)->Quotekeys(0)->Dump;
}

sub get_session_data {
  my ($self, $key) = @_;

  my ($prefix, $id) = split(/:/, $key);

  my $found = $self->_collection->find_one({ _id => $id },
    { $prefix => 1, 'expires' => 1 });

  return undef unless $found;

  if ($found->{expires} && time() > $found->{expires}) {
    $self->delete_session_data($id);
    return undef;
  }

  return eval($found->{$prefix});
}

sub store_session_data {
  my ($self, $key, $data) = @_;

  my ($prefix, $id) = split(/:/, $key);

  # we need to not serialize the expires date, since it comes in as an
  # integer and we need to preserve that in order to be able to use
  # mongodb's '$lt' function in delete_expired_sessions()
  my $serialized;
  if ($prefix =~ /^expires$/) {
    $serialized = $data;
  } else {
    $serialized = $self->_serialize($data);
  }

  $self->_collection->update({ _id => $id },
    { '$set' => { $prefix => $serialized } }, { upsert => 1 });
}

sub delete_session_data {
  my ($self, $key) = @_;

  my ($prefix, $id) = split(/:/, $key);

  my $found = $self->_collection->find_one({ _id => $id });
  return unless $found;

  if (exists($found->{$prefix})) {
    if ((scalar(keys(%$found))) > 2) {
      $self->_collection->update({ _id => $id },
        { '$unset' => { $prefix => 1 }} );
      return;
    } else {
      $self->_collection->remove({ _id => $id });
    }
  }
}

sub delete_expired_sessions {
  my ($self) = @_;

  $self->_collection->remove({ 'expires' => { '$lt' => time() } });
}

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Catalyst::Plugin::Session::Store::MongoDB - MongoDB session store for Catalyst

=head1 SYNOPSIS

In your MyApp.pm:

  use Catalyst qw/
    Session
    Session::Store::MongoDB
    Session::State::Cookie # or similar
  /;

and in your MyApp.conf

  <Plugin::Session>
    hostname foo    # defaults to localhost
    port 0815    # defaults to 27017
    dbname test    # defaults to catalyst
    collectionname s2  # defaults to session
  </Plugin::Session>

Then you can use it as usual:

  $c->session->{foo} = 'bar'; # will be saved

=head1 DESCRIPTION

C<Catalyst::Plugin::Session::Store::MongoDB> is a session storage plugin using
MongoDB (L<http://www.mongodb.org>) as its backend.

=head1 USAGE

=over 4

=item B<Expired Sessions>

This store automatically deletes sessions when they expire. Additionally it
implements the optional delete_expired_sessions() method.

=back

=head1 AUTHOR

  Ronald J Kimball, <rjk@tamias.net>

Previous Authors

  Stefan Völkel, <bd@bc-bd.org> <http://bc-bd.org>
  Cory G Watson, <gphat at cpan.org>

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License v2 as published
by the Free Software Foundation; or the Artistic License.

=cut
