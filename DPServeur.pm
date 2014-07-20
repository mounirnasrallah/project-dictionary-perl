package DPServeur;

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use Sys::Hostname;
use Digest::MD5 qw /md5_hex/;

use constant DEBUG => 1;

BEGIN {
    use Exporter ();
    use vars qw/$VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS/;
    $VERSION = 1.00;
    @ISA = qw(Exporter);
    @EXPORT = qw/&welcome &gestion_requetes/;
    %EXPORT_TAGS = ();
    @EXPORT_OK = qw/&welcome &gestion_requetes/;
}

my $dict_rep = "data";
my %commands_help = (
    "DEFINE database word" =>"Look up word in database",
    "MATCH database strategy word" => "Match word in database",
    "SHOW DB" => "List all accessible databases",
    "SHOW DATABASES" => "List all accessible databases",
    "SHOW STRAT"=>"List available matching strategies",
    "SHOW STRATEGIES"=> "List available matching strategies",
    "SHOW INFO database" => "Provide database information",
    "SHOW SERVER" => "Provide site-specific information",
    "CLIENT info" => "Identify client to server",
    "STATUS" => "Display timing information",
    "HELP" => "Display this help information",
    "QUIT" => "Terminate connection"
    );

my @commands = qw/QUIT DEFINE SHOW OPTION STATUS MATCH HELP/;

my $debut;

my %strategies = (
    "exact" => "Cherche une correspondance exacte (insensible à la casse)", 
    "re" => "Cherche une correspondance considé́rant word comme une expression é ́guèe`re conforme aux ERE.",
    "prefix" => "Cherche une correspondance considé́rant word comme un pé ́fixe (insensiblàa` la casse)",
    "suffixe" => "Cherche une correspondance considé́rant word comme un suffixe (insensibleà` la casse)",
    "regexp" => "Cherche une correspondance considé́rant word comme une expression reégulière conforme aux BRE."
);

sub welcome {
    my $client = shift;
    $debut = localtime();
    my $msg_id = md5_hex ($debut);
    my $hostname = hostname();
    $msg_id .= '@'.$hostname;
    print $client "220 $hostname Bienvenue sur notre serveur ! <html.mime> $msg_id";
}

sub quit_command {
    my $client = shift;
    print $client "221 Closing connection";
    $client -> shutdown(2);
    exit;
}

my $b64_codes = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
sub base64_decode {
    my @encode = split //, shift;
    my $s = 0;
    while (@encode) {
	$s *= 64;
	$s += index $b64_codes, shift(@encode);
    }
    return $s;
}

sub read_definitions(){
    
    my $db =shift;
    my $decalage = shift;
    my $longueur = shift;
    
    open my $fh, $dict_rep."/".$db.".dict"
	or die "Ne peut pas ouvrir le fichier $db.dict:$!";
    
    seek $fh, $decalage, 0;
    my $definition = undef;
    sysread $fh, $definition, $longueur or
	warn "Ne peut pas lire la definition: $!";
    
    close $fh or die "Ne peut pas fermer le fichier: $!";
    
    return $definition;
}

sub search_define{
    my $db = shift;
    my $mot = shift;
    my $strategie = shift;
    
    my @results;

    my $definition;
    
    open my $fh,$dict_rep."/".$db.".index"
	or die "Ne peut pas ouvrir le fichier $db.index:$!";
    print "(DEFINE) mot cherche $mot" if DEBUG;
    
    while (my $ligne = <$fh>) {
	if($ligne =~ m|^00databaseshort\t([+\w/]+)\t([+\w/]+)$|) {
	    my $decalage = base64_decode($1);
	    my $longueur = base64_decode($2);
	    $definition = &read_definitions($db,$decalage,$longueur);
	    chomp $definition;
	}
	
	if ($ligne =~ m|^$mot\t([+\w/]+)\t([+\w/]+)$|) {
	    my $decalage = base64_decode($1);
	    my $longueur = base64_decode($2);
	    
	    unless($strategie =~/\!/ || $strategie =~/\*/){
		push @results, "151 word $db $definition \n".&read_definitions($db,$decalage,$longueur).".";
	    }
	    else{
		if($strategie =~/\!/){
		    push @results, "151 word $db $definition".&read_definitions($db,$decalage,$longueur).".";
		    goto end_search;
		}
		elsif($strategie =~/\*/){
		    push @results, "151 word $db $definition".&read_definitions($db,$decalage,$longueur).".";
		}
	    }
	}	
    }
  end_search:
    close $fh or die "Ne peut pas fermer le fichier: $!";
    
    return @results;
    
}

sub define_command {

    my $client = shift;
    my $database = shift;
    my $mot = shift;
    my @results;

    if ($database =~ /^\*$/ || $database =~ /^\!$/ ) {
	opendir my $directory, $dict_rep."/" or die "Probleme de repertoire de la bdd : $!";
	my @files_db = readdir $directory;
	foreach (@files_db){
	    if(/(.*)\.index$/){
		my @tmp = &search_define($1,$mot,$database);
		if(@tmp){
		    push @results, @tmp;
		    if($database =~ /^\!$/){
			goto end_search;
		    }
		}
	    }
	}
      end_search:
	close $directory;
    }
    else {
	if(-f $dict_rep."/".$database.'.dict' && -f $dict_rep."/".$database.'.index'){
	    my @tmp = &search_define($database,$mot,$database);
	    if(@tmp){
		push @results, @tmp;
	    }
	}
	else{
	    print $client "550 Invalid database";
	    print $client ".";
	    print $client "250 Command compelete";
	    return;
	}
    }
    
    my $nbr_found = scalar @results;
    
    if($nbr_found>0){
	print $client "151 $nbr_found definitions found: list follows";
	foreach (@results){
	    print $client $_;
	}
	print $client ".";
	print $client "250 Command compelete";	
    }
    else{
	print $client "552 No match";
	print $client ".";
	print $client "250 Command compelete";
    }

}

sub match_strategy{

    my $strategy = shift;
    my $word = shift;

    my $expr;

    if($strategy =~ /exact/){
	$expr = "^".$word;
    }

    if($strategy =~ /re/){
	$expr = $word;
    }

    if($strategy =~ /prefix/){
	$expr = "^".$word."[^\t]*";
    }

    if($strategy =~ /suffixe/){
	$expr = "^[^\t]".$word;
    }

    if($strategy =~ /regexp/){
	$expr = $word;
    }

    
    return $expr;
}


sub match_command{
    my $client = shift;
    my $database = shift;
    my $strategy = shift;
    my $word = shift;
    my @result = ();
    
    unless($strategy =~ /exact/ || $strategy =~ /re/  || $strategy =~ /prefix/ || $strategy =~ /suffix/){
	print $client "551 Invalid strategy";
	return;
    }
    else{
	if($database =~ /\*/ || $database =~ /\!/ ){
	    opendir my $directory, $dict_rep."/" or die "Probleme de repertoire de la bdd : $!";
	    my @files_db = readdir $directory;
	    
	    foreach (@files_db){
		if(/.*\.index$/){

		    open my $dictionary, $dict_rep."/".$_ or die "Ne peut pas ouvrir le fichier: $!"; 
		    
		    my $expr = &match_strategy($strategy,$word);
		   
		    while(my $ligne = <$dictionary>){
			
			if ($ligne =~ m|($expr)\t([+\w/]+)\t([+\w/]+)$|) {
			    push @result,"$_ $1";
			    if($database =~ /\!/){
				goto end_search;
			    }
			}
		    }
		    close $dictionary;
		}
	    }
	    
	  end_search:
	    
	    my $nbr_found = scalar @result;
	    
	    if($nbr_found>0){
		print $client "152 $nbr_found definitions found: list follows";
		foreach (@result){
		    print $client $_;
		}
		print $client ".";
		print $client "250 Command compelete";
		$client->flush;
	    }
	    else{
		print $client "552 No match";
		print $client ".";
		print $client "250 Command compelete";
		$client->flush;
	    }
	}
    }
}


sub show_command{
    my $client = shift;
    my $sub_command = shift;
    my $db_info= shift;
    

    if($sub_command =~ m/^(DB|DATABASES)$/i ){
	my @result = ();
	opendir my $directory, $dict_rep or die "Probleme de repertoire de la bdd : $!";
	my @files_db = readdir $directory;
	
	foreach my $tmp (@files_db){
	    if($tmp =~ m/(.*)\.index$/){
		open my $dictionary, $dict_rep."/".$tmp or die "Ne peut pas ouvrir le fichier: $!"; 
		my $ligne;
		my $namedb = $1;
		while($ligne = <$dictionary>){
		    if($ligne =~ m|^00databaseshort\t([+\w/]+)\t([+\w/]+)$|) {
			my $decalage = base64_decode($1);
			my $longueur = base64_decode($2);
			my $definition = &read_definitions($namedb,$decalage,$longueur);
			
			chomp $definition;		      
			push @result, "$namedb $definition";
			goto end;
		    }
		}
	      end:
		close $dictionary;
	    }   
	}
	
	my $nbr_result = scalar @result;
	
	if($nbr_result > 0){
	    print $client "111 $nbr_result databases present: list follows";
	    foreach (@result){
		print $client $_;
	    }
	    print $client ".\n";
	    print $client "250 Command complete";
	    $client->flush;
	}
	else{
	    print $client "554 No databases present";
	}
    }
    
    elsif($sub_command =~ m/^(STRAT|STRATEGIES)$/i ){
	my $nbr_strategies= scalar (keys %strategies);
	if($nbr_strategies>0){
	    print $client "111 $nbr_strategies strategies available:";
	    foreach my $key (keys %strategies){
		print $client "$key \t\t $strategies{$key}";
	    }
	    print $client ".\n";
	}
	else{
	    print $client "555 No strategies available";
	}
    }
    
    elsif($sub_command =~ m/^SERVER$/i ){
	my $hostname = hostname();
	my $addr = $client->sockhost();
	my $port = $client->sockport(); 
	chomp $hostname;
	print $client "Machine : $hostname";
	print $client "Adresse : $addr";
	print $client "Port : $port";
	print $client ".\n";
	print $client  "250 Command complete";
	$client->flush;
    }
    
    elsif($sub_command =~ m/^INFO$/i ){

	my @result;
	
	if(-f $dict_rep."/".$db_info.".dict" && -f $dict_rep."/".$db_info.".index" ){
	    open my $dictionary, $dict_rep."/".$db_info.".index" or die "Ne peut pas ouvrir le fichier: $!";
	    my $ligne;
	    
	    while($ligne = <$dictionary>){
		if($ligne =~ m|^00databaseinfo\t([+\w/]+)\t([+\w/]+)$|) {
		    my $decalage = base64_decode($1);
		    my $longueur = base64_decode($2);
		    my $definition = &read_definitions($db_info,$decalage,$longueur);
		    chomp $definition;
		    push @result, "$db_info $definition";
		    goto end;
		}
	    }
	  end:
	    close $dictionary;


	    print $client "112 database information follows";
            print $client "@result";
	    print $client ".\n";
            print $client  "250 Command complete";
	    $client->flush;
	}
	else{
	    print $client "550 Invalid database, use SHOW DB for a list";
	    print $client ".\n";
	    print $client  "250 Command complete";
	    $client->flush;
	}
    }
    
}


sub status_command{
    my $client = shift;

    print $client "210 $$ $^T";
}

sub help_command{

    my $client = shift;   

    my $nbr_commands = length %commands_help;

    print $client "113 $nbr_commands text follows\n";
    
    foreach my $key (keys %commands_help){
	print $client "$key \t\t-- %commands_help{$key}";
    }
    
    print $client ".\n";
    print $client "250 Command complete";
}



sub gestion_requetes {
    
    my $client = shift;
    my $requete = shift;

    if ($requete =~ /^QUIT$/i) {
	&quit_command($client);
    }
    elsif ($requete =~ m|^DEFINE ([-\w\.\*\!]+) ([-\w\. ]+)\s*$|i) {
	&define_command ($client, $1, $2);
    }
    elsif ($requete =~ m/^MATCH ([-\w\*\!]) (\w+) ([-\w.]+)$/i){
	&match_command($client,$1,$2,$3);
    }
    elsif ($requete =~ m/^HELP$/i){
	&help_command($client);
    } 
    elsif ($requete =~ /^SHOW (DB|DATABASES|STRAT|STRATEGIES|SERVER)\s*$/i){
	&show_command($client,$1);
    }
    elsif($requete =~ /^SHOW (INFO) ([\w\.\-]+)\s*$/i){
	&show_command($client,$1,$2);
    }
    elsif ($requete =~ /^STATUS$/i){
	&status_command($client);
    }

    elsif (scalar (grep { $requete =~ /^$_$/i } @commands) == 1) {
	print $client "502 Command not implemented";
    }
    else {
	print $client "500 Syntax error, command not recognized";
    }
}

1;
