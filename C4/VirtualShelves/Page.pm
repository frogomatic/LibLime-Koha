package C4::VirtualShelves::Page;

#
# Copyright 2000-2002 Katipo Communications
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

# perldoc at the end of the file, per convention.

use strict;
use warnings;
use CGI;
use C4::VirtualShelves;
use C4::Biblio;
use C4::Items;
use C4::Auth;
use C4::Output;
use Exporter;

use vars qw($debug @EXPORT @ISA $VERSION);

BEGIN {
	$VERSION = 1.00;
	@ISA = qw(Exporter);
	@EXPORT = qw(&shelfpage);
    $debug = $ENV{DEBUG} || 0;
}

our %pages = (
	intranet => {
		redirect=>'/cgi-bin/koha/virtualshelves/shelves.pl',
	},
	opac => {
		redirect=>'/cgi-bin/koha/opac-shelves.pl',
	},
);

sub shelfpage ($$$$$) {
	my ($type, $query, $template, $loggedinuser, $cookie ) = @_;
	($pages{$type}) or $type = 'opac';
	$query or die "No query";
	$template or die "No template";

# the format of this is unindented for ease of diff comparison to the old script

if ( $query->param('modifyshelfcontents') ) {
    my $shelfnumber = $query->param('viewshelf');
    my $barcode     = $query->param('addbarcode');
    my ($item) = GetItem( 0, $barcode );
    my ($biblio) = GetBiblioFromItemNumber($item->{'itemnumber'});
    if ( ShelfPossibleAction( $loggedinuser, $shelfnumber, 'manage' ) ) {
        AddToShelf( $biblio->{'biblionumber'}, $shelfnumber );
        foreach ( $query->param ) {
			/REM-(\d*)/ or next;
			$debug and warn "SHELVES: user $loggedinuser removing item $1 from shelf $shelfnumber";
			DelFromShelf( $1, $shelfnumber );	 # $1 is biblionumber
        }
    }
}

my $showadd = 1;
# set the default tab, etc. (for OPAC)
my $shelf_type = $query->param('display');
if (defined $shelf_type) {
	if ($shelf_type eq 'privateshelves')  {
		$template->param(showprivateshelves => 1);
	} elsif ($shelf_type eq 'publicshelves') {
		$template->param(showpublicshelves => 1);
		$showadd = 0;
	} else {
		$debug and warn "Invalid 'display' param ($shelf_type)";
	}
} else {
	$template->param(showprivateshelves => 1);
}

# getting the Shelves list
my $shelflist = GetShelves( $loggedinuser, 2 );
$template->param( { loggedinuser => $loggedinuser } );
my $op = $query->param('op');

SWITCH: {
	if ( $op ) {
		if ( $op eq 'modifsave' ) {
			ModShelf(
				$query->param('shelfnumber'), $query->param('shelfname'),
				$loggedinuser,                $query->param('category'), $query->param('sortfield')
			);
			$shelflist = GetShelves( $loggedinuser, 2 );    # refresh after mods
		} elsif ( $op eq 'modif' ) {
			my ( $shelfnumber, $shelfname, $owner, $category, $sortfield ) =GetShelf( $query->param('shelf') );
			$template->param(
				edit                => 1,
				shelfnumber         => $shelfnumber,
				shelfname           => $shelfname,
				"category$category" => 1,
				"sort_$sortfield"   => 1,
			);
		}
		last SWITCH;
	}
    if ( $query->param('viewshelf') ) {
        #check that the user can view the shelf
        my $shelfnumber = $query->param('viewshelf');
        if ( ShelfPossibleAction( $loggedinuser, $shelfnumber, 'view' ) ) {
            my $items = GetShelfContents($shelfnumber);
			$showadd = 1;
			my $i = 0;
			foreach (grep {$i++ % 2} @$items) {     # every other item
				$_->{toggle} = 1;
			}
			# my $manageshelf = &ShelfPossibleAction( $loggedinuser, $shelfnumber, 'manage' );
			# ($manageshelf) and $showadd = 1;
            $template->param(
                shelfname   => $shelflist->{$shelfnumber}->{'shelfname'},
                shelfnumber => $shelfnumber,
                viewshelf   => $query->param('viewshelf'),
                manageshelf => &ShelfPossibleAction( $loggedinuser, $shelfnumber, 'manage' ),
                itemsloop => $items,
            );
        }
        last SWITCH;
    }
    if ( $query->param('shelves') ) {
        if ( my $newshelf = $query->param('addshelf') ) {
            my $shelfnumber = AddShelf(
                $newshelf,
                $query->param('owner'),
                $query->param('category')
            );

            if ( $shelfnumber == -1 ) {    #shelf already exists.
				$showadd = 1;
                $template->param(
                        shelfnumber => $shelfnumber,
                        already     => 1
                );
            } else {
            	print $query->redirect($pages{$type}->{redirect} . "?viewshelf=$shelfnumber");
            	exit;
			}
        }
        my @paramsloop;
        foreach ( $query->param() ) {
            /DEL-(\d+)/ or next;
			my $number = $1;
            my %line;
			if (defined $shelflist->{$number}) {
				my $name = $shelflist->{$number}->{'shelfname'};
				if (DelShelf($number)) {
					delete $shelflist->{$number};
					$line{delete_ok}   = $name;
				} else {
					$line{delete_fail} = $name;
				}
			} else {
				$line{unrecognized} = $number;
	  		}
			push(@paramsloop, \%line);
            # print $query->redirect("/cgi-bin/koha/virtualshelves/shelves.pl"); exit;
		}
		$showadd = 1;
		$template->param(
			paramsloop => \@paramsloop,
			shelves    => 1,
		);
		last SWITCH;
	}
}

# rebuild shelflist in case a shelf has been added
$shelflist = GetShelves( $loggedinuser, 2 );
$showadd and $template->param(showadd => 1);
my $i = 0;
my @shelvesloop;
my @shelveslooppriv;
my $numberCanManage = 0;

foreach my $element (sort { lc($shelflist->{$a}->{'shelfname'}) cmp lc($shelflist->{$b}->{'shelfname'}) } keys %$shelflist) {
	my %line;
	(++$i % 2) and $line{'toggle'} = $i;
	$line{'shelf'}             = $element;
	$line{'shelfname'}         = $shelflist->{$element}->{'shelfname'};
	$line{'shelfvirtualcount'} = $shelflist->{$element}->{'count'};
	$line{'sortfield'}         = $shelflist->{$element}->{'sortfield'};
	$line{"viewcategory$shelflist->{$element}->{'category'}"} = 1;
	$line{'canmanage'} = ShelfPossibleAction( $loggedinuser, $element, 'manage' );
	if ($shelflist->{$element}->{'owner'} eq $loggedinuser) {
		$line{'mine'} = 1;
	} else {
		$line{'firstname'} = $shelflist->{$element}->{'firstname'};
		$line{'surname'}   = $shelflist->{$element}->{'surname'}  ;
	}
	$numberCanManage++ if $line{'canmanage'};
	if ($shelflist->{$element}->{'category'} eq '1') {
		push (@shelveslooppriv, \%line);
	} else {
		push (@shelvesloop, \%line);
	}
}

$template->param(
    shelveslooppriv => \@shelveslooppriv,
    shelvesloop     => \@shelvesloop,
    shelvesloopall  => [(@shelvesloop, @shelveslooppriv)],
    numberCanManage => $numberCanManage,
	"BiblioDefaultView".C4::Context->preference("BiblioDefaultView") => 1,
);
if ($template->param('viewshelf') or
	$template->param( 'shelves' ) or
	$template->param(  'edit'   ) ) {
	$template->param(vseflag => 1);
}
if ($template->param( 'shelves' ) or
	$template->param(  'edit'   ) ) {
	$template->param( seflag => 1);
}

output_html_with_http_headers $query, $cookie, $template->output;
}	

1;
__END__

=head1 NAME

    VirtualShelves/Page.pm

=head1 DESCRIPTION

    Module used for both OPAC and intranet pages.

=head1 CGI PARAMETERS

=over 4

=item C<modifyshelfcontents>

    If this script has to modify the shelf content.

=item C<shelfnumber>

    To know on which shelf to work.

=item C<addbarcode>

=item C<op>

    Op can be equals to:
        * modifsave to save change on the shelves
        * modif to change the template to allow to modify the shelves.

=item C<viewshelf>

    To load the template with 'viewshelves param' which allow to read the shelves information.

=item C<shelves>

    If equals to 1. then call the function shelves which add
    or delete a shelf.

=item C<addshelf>

    If the param shelves = 1 then addshelf must be equals to the name of the shelf to add.

=back

=cut