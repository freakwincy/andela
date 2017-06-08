#!/usr/bin/perl

use strict;
use warnings;
use Cwd;
use DBI;
use Readonly;
use Data::Dumper;
use Mojolicious::Lite;

$0 =~ /.*\/([^\/].*)\.pl$/;
my $fullPath  = $0;
my @url       = split( /\//, $fullPath );
my $arraysize = @url;
$arraysize--;
my $scriptName = $url[$arraysize];
my $script     = $scriptName;
$script =~ s/\.pl$//;

# Location of our software - default is '/usr/local/chimera'
# For testing, set the environment variable 'CHIMERA' to the full path of
# the directory containing your 'chimera' directory.
our $CHIMERA;

BEGIN {
    $CHIMERA =
      ( exists( $ENV{'CHIMERA'} ) ) ? $ENV{'CHIMERA'} : getcwd;
}

# Location of config file
my $config_file = "$CHIMERA/config/$script" . ".conf";

# Location of SQL library
my $sql_lib = "$CHIMERA/config/$script" . ".sql";

my $cfg = new Config::Simple($config_file);

# getting the values as a hash:
# my %Config = $cfg->vars();

# print 'Config: ' . Dumper(\%Config);

my $db_connection_hashref = $cfg->get_block('db');

my $DB_USER = $cfg->param('db.user');
my $DB_NAME = $cfg->param('db.name');
my $DB_PORT = $cfg->param('db.port');
my $DB_HOST = $cfg->param('db.host');
my $DB_PASS =
  ( defined $db_connection_hashref->{'pass'}
      && length( $db_connection_hashref->{'pass'} ) > 0 )
  ? $db_connection_hashref->{'pass'}
  : undef;

# valid numbers run from 1111111111 - 9999999999
Readonly my $MINIMUM    => 1111111111;
Readonly my $MAXIMUM    => 9999999999;

my $num_count = $MAXIMUM - $MINIMUM + 1;

# /getRandNumber?number=123456789
get '/getRandomNumber' => sub {
  my $c    = shift;

  my $number = &getRandomNumber();  
  if(defined $number) {  
    $c->render(text => "You have been assigned the number $number.");
  } else {
    $c->render(text => "Sorry, we're out of numbers in the current pool.");
  } 
};

# /getCustomNumber?number=6475309
get '/getCustomNumber' => sub {
  my $c    = shift;
  my $number = $c->param('number');
  if(defined &getUserSpecifiedNumber($number)) {
    $c->render(text => "You have been assigned the self-selected number $number.");
  } else {
    $c->render(text => "Sorry, we're out of numbers in the current pool.");
  }
};

app->start;

sub getRandomNumber {
    my $number = $MINIMUM;

    my %seen = ();

    # keep a running tally of previously seen numbers to prevent an infinite loop 
    while(&NumberIsInUse($number) == 1 && scalar keys(%seen) != $num_count) {
        if(!defined $seen{$number}) {
            # get a random value within our range of (potentially) assignable numbers
            $number = $MINIMUM + int(rand($MAXIMUM - $MINIMUM)) + 1;
            $seen{$number} = 1;
        }
    }
    if(&NumberIsInUse($number) == 1) {
        return undef;
    } else {
        # update active flag in DB
        
        return $number;
    }
}

sub getUserSpecifiedNumber {
    my $digits = @_;

    my $retval = undef;

    if($digits > $MINIMUM && $digits < $MAXIMUM) {
        if(&NumberIsInUse($digits) == 1) {
            return $retval;
        } else {
            return $digits;
        }
    } else {
        return $retval;
    } 
}

sub assignNumber {
    my ($num, $dbh) = @_; 

    my $lib = SQL::Library->new( { lib => $sql_lib } );
    my $sql = $lib->retr('assign_number');
    my $sth = $dbh->prepare($sql)
      or die "preparing: ", $dbh->errstr;

    $sth->execute( $num )
        or die "executing: ", $dbh->errstr;
}

sub NumberIsInUse {
    my ($num) = @_; 

    my $inUse = 0;

    my $dbh =
      &getDBH( $DB_USER, $DB_PASS, $DB_HOST, $DB_PORT, $DB_NAME );

    my $lib = SQL::Library->new( { lib => $sql_lib } );
    my $sql  = $lib->retr('check_availability');
    my $sth  = $dbh->prepare($sql)
      or die "preparing: ", $dbh->errstr;

    $sth->execute( $num ) or die "executing: ", $dbh->errstr;

    while ( my $row = $sth->fetchrow_hashref('NAME_lc') ) {
        $inUse = $row->{'active'};
    }
    return $inUse;
}

sub getDBH {
    my ( $DB_USER, $DB_PASS, $DB_HOST, $DB_PORT, $DB_NAME ) = @_;

    my $dbh = undef;

    if ( defined($DB_PASS) ) {
        $dbh = DBI->connect(
            "dbi:mysql:host=$DB_HOST;port=$DB_PORT;database=$DB_NAME",
            $DB_USER, $DB_PASS )
          || die "unable to connect to $DB_NAME: $DBI::errstr\n";
    }
    else {
        $dbh = DBI->connect(
            "dbi:mysql:host=$DB_HOST;port=$DB_PORT;database=$DB_NAME",
            $DB_USER )
          || die "unable to connect to $DB_NAME: $DBI::errstr\n";
    }

    $dbh->{AutoCommit} = 1;
    $dbh->{RaiseError} = 1;
    $dbh->{PrintError} = 0;

    return $dbh;
}
