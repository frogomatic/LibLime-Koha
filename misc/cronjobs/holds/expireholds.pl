#!/usr/bin/perl
# run nightly -- remove holds that are later than waitingdate +
# ReservesMaxPickUpDelay from the reserves table.
#
# Copyright 2011 LibLime, a Division of PTFS, Inc.
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA

=head1 NAME

expireholds.pl - cron script to remove expired holds from the reserves table

=head1 SYNOPSIS

./expireholds.pl

or, in crontab:
0 1 * * * $KOHA_CRON_DIR/holds/expireholds.pl

=head1 DESCRIPTION

This script simply removes holds in the reserves table that have expired.
Previously, the ReservesMaxPickUpDelay syspref was being used to display
that holds had expired, but they were not being deleted from the reserves
table.  This script corrects that problem.

=cut

use strict;
BEGIN {
    # find Koha's Perl modules
    # test carefully before changing this
    use FindBin;
    eval { require "$FindBin::Bin/../kohalib.pl" };
}

use C4::Context;
use C4::Dates;
use C4::Members;
use C4::Biblio;
use C4::Letters;
use C4::Reserves;
use C4::Members::Messaging;
my $today     = C4::Dates->new();
my $today_iso = $today->output('iso');

my $dbh = C4::Context->dbh;
my $query = "SELECT * FROM reserves
             WHERE expirationdate < ?";
my $sth = $dbh->prepare($query);
$sth->execute($today_iso);
while (my $expref = $sth->fetchrow_hashref) {
  C4::Reserves::_moveToOldReserves($expref->{reservenumber});

  # Send expiration notice, if desired
  my $borrowernumber = $expref->{borrowernumber};
  my $biblionumber = $expref->{biblionumber};
  my $branchcode = $expref->{branchcode};
  my $mprefs = C4::Members::Messaging::GetMessagingPreferences( {
    borrowernumber => $borrowernumber,
    message_name   => 'Hold Expired'
  } );
  if ( $mprefs->{'transports'} ) {
    my $borrower = C4::Members::GetMember( $borrowernumber, 'borrowernumber');
    my $biblio = GetBiblioData($biblionumber) or die sprintf "BIBLIONUMBER: %d\n", $biblionumber;
    my $letter = C4::Letters::getletter( 'reserves', 'HOLD_EXPIRED');
    my $admin_email_address = C4::Context->preference('KohaAdminEmailAddress');

    my %keys = (%$borrower, %$biblio);
    $keys{'branchname'} = C4::Branch::GetBranchName( $branchcode );
    my $replacefield;
    foreach my $key (keys %keys) {
      foreach my $table qw(biblio borrowers branches items reserves) {
        $replacefield = "<<$table.$key>>";
        $letter->{content} =~ s/$replacefield/$keys{$key}/g;
      }
    }

    C4::Letters::EnqueueLetter(
      { letter                 => $letter,
        borrowernumber         => $borrower->{'borrowernumber'},
        message_transport_type => $mprefs->{'transports'}->[0],
        from_address           => $admin_email_address,
        to_address             => $borrower->{'email'},
      }
    );
  }
}
$dbh->disconnect();
