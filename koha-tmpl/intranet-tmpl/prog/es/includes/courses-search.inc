
<h1 id="logo"><a href="/cgi-bin/koha/mainpage.pl"><!-- TMPL_VAR NAME="LibraryName" --></a></h1>
<div id="header_search">
	<div id="notices_search" class="residentsearch">
	<p class="tip">Search course reserves by name, department, course number, term, notes or instructor name:</p>
<form action="/cgi-bin/koha/circ/courses.pl" method="get">
		<input type="text" name="limit" size="40" value="" />
                <input type="submit" class="submit" name="submit" value="Buscar">
        </form>	
	</div>
			<ul>
			<li><a href="/cgi-bin/koha/admin/courses.pl#courses_search">Search Course Reserves</a></li>
			</ul>	
</div>
<!-- End Course Reserves Resident Search Box -->
