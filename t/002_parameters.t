use strict;
use warnings;

use FindBin qw/$Bin/;
use lib "$Bin/lib";

use Test::More;

BEGIN {
	my @needs = qw/MONGODB_HOST MONGODB_PORT TEST_DB TEST_COLLECTION/;

	map {
		plan skip_all => 'Must set '.join(",", @needs).
			' environment variables'	unless(defined($ENV{$_}));
	} @needs;
}

use_ok('Catalyst::Plugin::Session::Store::MongoDB');

my $store = Catalyst::Plugin::Session::Store::MongoDB->new(
	hostname => $ENV{MONGODB_HOST},
	port => $ENV{MONGODB_PORT},
	dbname => $ENV{TEST_DB},
	collectionname => $ENV{TEST_COLLECTION}, );

# parameters
is ( $store->hostname, $ENV{MONGODB_HOST}, 'parameters::hostname' );
is ( $store->port, $ENV{MONGODB_PORT}, 'parameters::' );
is ( $store->dbname, $ENV{TEST_DB}, 'parameters::db' );
is ( $store->collectionname, $ENV{TEST_COLLECTION}, 'parameters::collection' );

done_testing()
