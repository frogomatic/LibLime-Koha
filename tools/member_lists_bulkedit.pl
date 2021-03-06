#!/usr/bin/perl


# Copyright 2000-2002 Katipo Communications
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

use strict;
use warnings;

use CGI;

use C4::Auth;
use C4::Context;
use C4::Output;
use C4::Koha;
use C4::Members;
use C4::Members::Lists;

my $input = new CGI;
my $list_id = $input->param('list_id');

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name   => "tools/member_lists_bulkedit.tmpl",
        query           => $input,
        type            => "intranet",
        authnotrequired => 0,
    }
);

my $list = GetList({ list_id => $list_id });
$template->param( %$list );

$template->param( BorrowerFieldsLoop => GetTableDescription({ table => 'borrowers' }) );

my @index_loop;
for ( my $i = 2; $i <= 100; $i++ ) {
    push( @index_loop, { index => $i, next_index => $i+1, prev_index => $i-1 } );
}
$template->param( IndexLoop => \@index_loop );

output_html_with_http_headers $input, $cookie, $template->output;
