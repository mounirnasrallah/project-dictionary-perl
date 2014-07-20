#!/usr/bin/perl -l

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use IO::Socket;

use DPClient;
use constant DEBUG => 1;

my $host = shift || "localhost";
my $port = shift || "2628";

my $mysock = IO::Socket::INET -> new (Proto => "tcp",
				      PeerAddr => "$host:$port")
    or die "Ne peut pas me connecter à $host:$port: $!";

my $command = undef;
my $reponse = undef;

$mysock -> autoflush(1);

print "Connexion reussie au serveur $host:$port" if DEBUG;

$reponse = <$mysock>;
print $reponse;

while (1) {
    printf "? ";
    $command = <stdin>;
    chomp $command;

    if ($command =~ /^q(uit)?\s*$/i) {
	print $mysock "QUIT";
	$reponse = <$mysock>;
	chomp $reponse;
	if ($reponse =~ /221 Closing connection/) {
	    print "Connexion terminee avec le serveur";
	    exit (0);
	}
	else {
	    print "Quelque chose de mal est arrivee: $reponse";
	}
    }
    elsif ($command =~ /^DEFINE\s+([-\w\!\*.]+)\s+([-\w. ]+)\s*$/i) {
	my $dico = $1;
	my $mot = $2;
	print $mysock "DEFINE $dico $mot";
	$reponse = <$mysock>;
	chomp $reponse;

	if (DPClient::is_error_response ($reponse)) {
	    print "$reponse\n";
	}

	else {
	    print $reponse;
	    my $ligne = undef;
	    while (1) {
		$ligne = <$mysock>;
		chomp $ligne;
		print $ligne;
		last if $ligne =~ /^250/;
	    }
	 
	}
    }
    
    elsif ($command =~ /^MATCH\s+([-\w.\*\!]+)\s+(exact|re|prefix|suffix|regexp)\s+([-\w.]+)$/i) {
	my $db = $1;
	my $strategy = $2;
	my $word = $3;
	
	print $mysock "MATCH $db $strategy $word";
	
	my $ligne = undef;
	
	while (1) {
	    $ligne = <$mysock>;
	    chomp $ligne;
	    print $ligne;
	    last if $ligne =~ /^\.$/;
	}
	
    }
    
    elsif($command =~ /^SHOW\s+INFO\s(.*)$/i){
        print $mysock "SHOW INFO $1";
        my $ligne = undef;
        while (1) {
            $ligne = <$mysock>;
            chomp $ligne;
            print $ligne;
	    last if $ligne =~ /^.$/;
        }
     }

    elsif($command =~ /^SHOW\s+(DB|DATABASES|STRAT|STRATEGIES|SERVER)\s*$/i){
	print $mysock "SHOW $1";
	
	my $ligne = undef;
        while (1) {
            $ligne = <$mysock>;
            chomp $ligne;
            print $ligne;
            last if $ligne =~ /^250/;
        }
	
    }
    

    elsif($command =~ /^STATUS\s*$/i){
	print $mysock "STATUS";

	my $ligne = undef;
        while (1) {
            $ligne = <$mysock>;
            chomp $ligne;
            print $ligne;
            last if $ligne =~ /^210/;
        }

	
    }

    elsif($command =~ m/^HELP\s*$/i ){
	
	print $mysock "HELP";
	
	my $ligne = undef;
	while (1) {
	    $ligne = <$mysock>;
	    chomp $ligne;
	    print $ligne;
	    last if $ligne =~ /^250/;
	}

    }


    else {
	print "Commande inconnue";
	print $mysock $command;
	$reponse = <$mysock>;
	chomp $reponse;

	if (DPClient::is_error_response ($reponse)) {
	    #print "Erreur recue: $reponse\n";
	}
	else {
	    print $reponse;
	}
    }
}


