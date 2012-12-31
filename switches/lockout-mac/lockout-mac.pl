#!/usr/bin/perl

#	Skrypt pokazuje informacje o switchu.
#
#	by Marek 'oczek' Oszczapiński <oczek@oczek.com>
# 
#	block and unblock mac addres on switch
#

use SNMP 
use warnings;

my $community = 'public';

print "Podaj IP switcha: ";
$IP = <STDIN>;
print "What to do? \n 1) Block MAC \n 2) Unblock MAC \n 3) Check Lockout-mac \n";
$WYBOR = <STDIN>;

if ( "$WYBOR" != "3" ) {
	print "Enter MAC: ";
	my $MAC = <STDIN>;
}

$MAC2 = mac2int.pl $MAC;

$session = new SNMP::Session(
		DestHost => $IP,
		Community => $community,
                Version => 2,
                Timeout => 100000,
                Retries => 1);

#die "session creation error: $SNMP::Session::ErrorStr" unless (defined $session);

if ( "$WYBOR" == 1 ) {
$varbz = new SNMP::Varbind(['1.3.6.1.2.1.17.7.1.3.1.1.4.4095.$MAC2.0'] ); 	#blokujemy
}
elsif ( "$WYBOR" == 2 ) {
$varbo = new SNMP::Varbind(['1.3.6.1.2.1.17.7.1.3.1.1.4.4095.$MAC2.0'] );				#odblokujemy
}
elsif ( "$WYBOR" == 3 ) {
$vars = new SNMP::VarList(['1.3.6.1.2.1.17.7.1.3.1.1.4.4095.$MAC2.0'] ); 				#sprawdzamy
}

my @SETz = $session->getnext($varbz);
my @SETo = $session->getnext($varbo);
my @LIST = $session->getnext($vars);

if ( "$WYBOR" == '1' ) {
    print "Zablokowany: $SET[0] \n";
}
elsif ( "$WYBOR" == '2' ) {
    print "Odblokowany: $SET[1] \n";
}
elsif ( "$WYBOR" == '3' ) {
    print "Zablokowane MACi: $LIST[0] \n";
}
