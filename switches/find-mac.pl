#!/usr/bin/perl


#	Wywolanie: ./switches.pl  
#
#	by Marek 'oczek' Oszczapiński <oczek@oczek.com>
#	
#	find mac on the switch HP ProCourve by snmp
#

use SNMP;
use Net::SNMP;
use warnings;
#use strict;
use Net::MAC;
use Data::Dumper;

#my $oid = '1.3.6.1.2.1.17.4.3.1.2.8.0.39.213.69.112';
#my $oid = '1.3.6.1.2.1.17.4.3.1.2';
my community = 'public';

sub snmpConnectWalk {
	my ($session, $error) = new SNMP::Session(
		DestHost => shift,
		Community => shift,
                Version => 2,
                Timeout => 100000,
                Retries => 1);
	if(!$session) {
                printf("Error: %s.\n", $error);
                exit(1);
	}
	return $session;
}

sub snmpConnect {
	my ($session, $error) = Net::SNMP->session(
                -hostname  => shift,
                -community => shift,
        );
        if(!$session) {
                printf("Error: %s.\n", $error);
                exit(1);
        }
        return $session;
}

sub snmpDisconnect {
        my $session = shift;
        $session->close();
}

sub mac2int {
        my $mac = Net::MAC->new('mac' => shift );

        my $dec_mac = $mac->convert(
                'base' => 10,
                'bit_group' => 8,
                'delimiter' => '.'
        );

}

my %switches = (
	# najpierw przejsciowe switche
	hp2.0 => { host => '10.0.2.0', mac => '00:00:00:00:00:02' },
	hp3.0 => { host => '10.0.3.0', mac => '00:00:00:00:00:03' },
); 

print "Enter mac-address: \n";
my $address = <STDIN>;
chomp $address;

print mac2int($address)." \n";

my $oid = '1.3.6.1.2.1.17.4.3.1.2.'.mac2int($address);

foreach my $sw (sort keys %switches) {

        my $hostname = $switches{$sw}->{'host'};
	my $address = $switches{$sw}->{'mac'};
	my $oid2 = '1.3.6.1.2.1.17.4.3.1.2.'.mac2int($address);

	my $portUser = snmpConnect($hostname, $community)->get_request($oid); # .mac2int($needle)) or print "Nie można się połączyć ze switchem";
	my $pU = $portUser->{$oid};
	
	$portSwitch = snmpConnect($hostname, $community)->get_request($oid2);
	my $pS = $portSwitch->{$oid2};

	if ($pU == $pS) {
		print "HOST: $hostname  Port: ".$portUser->{$oid}." \n";
	}

}
