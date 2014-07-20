package DPClient;

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use Switch;

use constant DEBUG => 1;

BEGIN {
    use Exporter ();
    use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
    $VERSION = 1.00;
    @ISA = qw(Exporter);
    @EXPORT = qw/&is_error_response/;
    %EXPORT_TAGS = ();
    @EXPORT_OK = qw/&is_error_response/;
}

sub is_error_response {
    my $reponse = shift;
    if ($reponse =~ /^(\d+)\s+([\w, ]+)$/ig) {
	switch ($1) {
	    case "500" { print $2; return 1;}
	    case "501" { print $2; return 1;}
	    case "502" { print $2; return 1;}
	    case "503" { print $2; return 1;}
	    case "550" { print $2; return 1;}
	    case "552" { print $2; return 1;}
	    case "420" { print $2; return 1;}
	    default { return 0; }
	}
    }
}

1;
