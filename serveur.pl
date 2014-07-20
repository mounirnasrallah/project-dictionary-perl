#!/usr/bin/perl -l

use strict;
use warnings;
use diagnostics;
diagnostics::enable;
use IO::Socket;

use DPServeur;
use constant DEBUG => 1;

my $port = shift || 2628;

my $server = IO::Socket::INET -> new (Proto => "tcp",
				LocalPort => $port,
				Listen => SOMAXCONN,
				Reuse => 1);

die "Ne peux pas créer de Socket sur le port $port: $!" unless $server;

print "Le serveur est en marche";

# pour ne pas avoir de processus zombie
$SIG{"CHLD"}="IGNORE";

while (my $client = $server -> accept() ) {
    print "Le serveur accepte une connexion" if DEBUG;

    my $pid = fork();
    if (!defined $pid) {
	print "Il y a une erreur dans le fork" if DEBUG;
	print $client "420 Server temporarily unavailable";
    }
    elsif ($pid) {
#	print "Je suis le pere" if DEBUG;
    }
    else {
	print "Je suis le fils" if DEBUG;
	$client -> autoflush(1);

	DPServeur::welcome($client);

	while (1) {
	    my $requete = <$client>;
	    chomp $requete;

	    print "Operation reçue: $requete" if DEBUG;

	    DPServeur::gestion_requetes($client,$requete);
	}
    }
}
