#!/usr/bin/perl

#	switches.pl
#
# 	Skrypt do odpytywania/konfiguracji switchy za pomocą snmp.
# 	Skrypt nie potrzebuje parametrów, o wszystko zostaniesz wypytany
# 	po uruchomieniu skryptu, wystarczy wtedy wybrać/podać co nas interesuje.
#
#	Wywolanie: ./switches.pl  
#
#	Author: Marek Oszczapiński <oczek<at>oczek.com>
#	Copyright (c) 2010, Marek Oszczapiński
#

# TODO:
# community jako parametr/zmienna w tej chwili trzeba zmieniac w skrypcie

use warnings;
use Net::SNMP;
use Net::MAC;
use Data::Dumper;

my $version = "0.3";

my $logfile = "/var/log/switches.log";
my $logging = 1;

if (@ARGV > 0) {
die <<ENDL;
\nswitches.pl (ver. $version)

Skrypt do odpytywania/konfiguracji switchy za pomocą snmp.
Skrypt nie potrzebuje parametrów, o wszystko zostaniesz wypytany
po uruchomieniu skryptu, wystarczy wtedy wybrać/podać co nas interesuje.

Author: Marek Oszczapiński <oczek<at>oczek.com>
Copyright (c) 2010, Marek Oszczapiński
ENDL
}

#
# Wszystkie OIDy
#
my $cpu = '1.3.6.1.4.1.11.2.14.11.5.1.9.6.1.0';
my $ios = '1.3.6.1.2.1.1.1.0';
my $uptime = '1.3.6.1.2.1.1.3.0';
my $memall = '1.3.6.1.4.1.11.2.14.11.5.1.1.2.1.1.1.5.1'; 
my $memused = '1.3.6.1.4.1.11.2.14.11.5.1.1.2.1.1.1.6.1'; 
my $macport = '1.3.6.1.4.1.11.2.14.11.5.1.9.4.2.1.2.';
my $name = '1.3.6.1.2.1.31.1.1.1.18.';
my $status = '1.3.6.1.2.1.2.2.1.7.';
my $sysname = '1.3.6.1.2.1.1.5.0';
my $location = '1.3.6.1.2.1.1.6';
my $contact = '1.3.6.1.2.1.1.4.0';
my $lockout = '1.3.6.1.2.1.17.7.1.3.1.1.4.4095';
my $reboot = '1.3.6.1.4.1.11.2.14.11.1.4.1.0';
my $vlan = '1.3.6.1.2.1.17.7.1.4.3.1.1';
my $vlans = '1.3.6.1.2.1.17.7.1.4.3.1.5';
my $dhcpsnoop = '1.3.6.1.4.1.11.2.14.11.5.1.34';

%switches = (
	# najpierw przejsciowe switche
	hp2.0 => { host => '10.0.2.0', mac => '00:00:00:00:00:00' },
); 

my ($sec,$min,$hour,$mday,$mon,$year,$wday,
$yday,$isdst)=localtime(time);
$mon+=1;
$year+=1900;
my $timestamp = sprintf("%02d/%02d/%04d %02d:%02d:%02d", $mday,$mon,$year,$hour,$min,$sec);

my $user = getpwuid($>);

sub writelog {
        my $logline = shift;
        if($logging == 1) {
                print LOGFILE "switches.pl $timestamp # $user - ".$logline."\n";
        }
}


sub snmpConnect {
	my ($session, $error) = Net::SNMP->session(
                -hostname  => shift,
                -community => shift || 'public-Community',
		-timeout => 1,
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
		'base' => shift,
        	'bit_group' => 8,
        	'delimiter' => '.'   
	); 
        $outmac = $dec_mac->get_mac();

}

sub hostname {
	print "Podaj IP switcha: ";
	chomp($hostname = <STDIN>);
}

sub porty {
        print "Podaj nr portu: \nGdy chcesz użyć kilka portów  - 1,2,8,10..15,48 ('..' - dla zakresu) \n";
        $PORT = <STDIN>;
        chomp ($PORT);
	@PORT = eval "$PORT";
}

sub rget {
	hostname;
	$oid = shift;
	my $re = snmpConnect($hostname)->get_request( $oid ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
	$res = $re->{$oid};
}

sub rget2 {
	my $oid = shift;
	my $re = snmpConnect($hostname)->get_request( $oid ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
	$res = $re->{$oid};
}

sub rset {
	hostname;
	my $oid = shift;
	my $value = shift;
	my $operator = shift;
	my $re = snmpConnect($hostname, 'Admin-Community')->set_request( $oid, $operator, $value ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";

}

sub rblock {
	my $value = shift;
	porty;
	hostname;
	foreach $port (@PORT) {
		$ports = $port;
		my $re = snmpConnect($hostname, 'Admin-Community')->set_request( '1.3.6.1.2.1.2.2.1.7.'.$port, INTEGER, $value ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
	}
}

sub findmac {
	print "Podaj mac-address: \n";
	chomp (my $address = <STDIN>);

	my $task = '00:0b:46:42:f0:00';

	foreach my $sw (sort keys %switches) {
		my $hostname = $switches{$sw}->{'host'};
		my $swadr = $switches{$sw}->{'mac'};
	        my $oid1 = '1.3.6.1.2.1.17.4.3.1.2.'.mac2int($address, 10);
	        my $oid2 = '1.3.6.1.2.1.17.4.3.1.2.'.mac2int($task, 10);
		
	 	my $portUser = snmpConnect($hostname)->get_request($oid1); # or die "Nie można się połączyć ze switchem \n";
		my $pU = $portUser->{$oid1}."\n";

		my $portSwitch = snmpConnect($hostname)->get_request($oid2)  or die "Nie można się połączyć ze switchem \n";
		my $pS = $portSwitch->{$oid2}."\n";
	
	        if ($pU ne $pS) {
	                print "Switch: $hostname Port: $pU";
	        }
#		else {
#			print "Mac-Address not found";
#		}
	}
}

sub lockoutmac {
	my $value = shift;
	hostname;
	print "Podaj Mac-Address: ";
	chomp($address = <STDIN>);
	my $lockoutmac = $lockout.'.'.mac2int($address, 10).'.0';
        my $re = snmpConnect($hostname, 'Admin-Community')->set_request( $lockoutmac, INTEGER, $value ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
#print Dumper $re;
#print $lockoutmac;
}

sub reboot {
	if (($user eq 'oczek' || $user eq 'podol' || $user eq 'start' )) {
		print "Czy na pewno chcesz zrestartować switcha?!? (y/n)\n";
		chomp ($choice = <STDIN>);

		rset( $reboot, INTEGER, 2);

		print "Switch $hostname został zrebootowany \n";
		writelog("Zrebootowano switcha $hostname");
	} else {
		print "Nie masz uprawnień do tej opcji!!! \n";
		writelog("Próba restartu switcha");
	}
}

my $repeat = shift;
until (lc ($repeat) eq "n" ) {

if ($logging == 1) {
        open(LOGFILE, ">> $logfile") || die "Error: Cannot open logfile: $logfile!\n";
}

print "Wybierz co chcesz sprawdzić, możliwe:
	1) Sprawdzić parametry i status
	2) Find-mac - znajdz MAC/port na switchu
	3) Konfiguracja switcha/portów
	4) Update switcha <- nie działa
	5) VLAN
	6) dhcp-snooping <- nie działa
	7) Zrestartuj switcha \n
	0) Zrezygnuj (działa także przy kolejnych wybieralnych opcjach) \n";
my $what = <STDIN>;

if ($what == 0 ) {exit;}

if ("$what" == '1') {
	print "Wybierz co chcesz sprawdzić, możliwe: \n\t1) Sprawdzić parametry switcha \n\t2) Sprawdzić parametry portu \n";
	$whats = <STDIN>;

	if ("$whats" == '1' ) {
		print "Wybierz co chcesz sprawdzić, możliwe: \n\t1) CPU \n\t2) uptime \n\t3) Pamięć cała \n\t4) Pamięć zużyta \n\t5) IOS \n\t6)Stacking <- nie działa";
		$choice = <STDIN>;
		if ($choice == "0" ) {exit;}
		
		elsif ($choice == 1) {
			rget($cpu);
			print "Zużycie CPU: ".$res ."% \n\a";
		}
		elsif ($choice == 2) {
			rget($uptime);
			print "Uptime: ".$res ." \n";
		}
		elsif ($choice == 3) {
			rget($memall);
			print "Cała pamięć: ".$res ." \n";
		}
		elsif ($choice == 4) {
			rget($memused);
			print "Pamięć zużyta: ".$res ." \n";
		}
		elsif ($choice == 5) {
			rget($ios);
			print "IOS: ".$res ." \n";
		}
		elsif ($choice == 6) {
			print "OPCJA NIEDOSTEPNA!!! \n";
		}
	}

	if ($whats == '2') {
		print "Wybierz co chcesz sprawdzić, możliwe: \n\t1) alias portu \n\t2) Sprawdzić status portu \n";
		chomp ($choice = <STDIN>);
		if ($choice == "0" ) {exit;}

		porty;
		hostname;

		foreach $port (@PORT) {
			if ($choice == '1') {
				rget2($name.$port);
				print "Nazwa dla portu $port ".$res ." \n\n";
			}
			elsif ($choice == '2') {
				rget2($status.$port);
				print "Status dla $port: ".$res ."\n\t 1 = UP, 2 = DOWN, 3 = TESTING \n\n";
			}
		}	
	}
}

if ( "$what" == '2' ) {
	print "Wybierz co chcesz zrobić, możliwe: \n\t1) Pokaż port dla MACa \n\t2) Pokaż Mac-Address dla portu \n";
	$choice = <STDIN>;
	if ($choice == "0" ) {exit;}

	elsif ($choice == '1') {
		findmac();
	}
	elsif ($choice == '2') {
		hostname;
		porty;
		
		foreach $port (@PORT) {
			my $PORTSmac = $macport.$port;
			my $re = `snmpwalk -v 2c -c public-Community $hostname $PORTSmac | cut -f4 -d":"` or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP/port? \n";

			print "Adress MAC dla portu $port: $re \n\n";
		}
	}
}

if ( "$what" == '3' ) {
print "Wybierz co chcesz zrobić, możliwe: \n\t1) Zmodyfikować port na switchu \n\t2) Zmodyfikować parametry switcha \n\t3) Lockout-mac\n";
$whats = <STDIN>;
	if ($whats == "0" ) {exit;}

	elsif ($whats == '1' ) {
		print "Wybierz co chcesz zrobić: \n\t1) Zablokować port switcha \n\t2) Odblokować port switcha \n\t3) Zmienić nazwę portu \n";
		$choice = <STDIN>;
		if ($choice == "0" ) {exit;}

		elsif ("$choice" == '1') {
			rblock ( 2 );
			print "Zablokowano: $hostname:\t $PORT \n";
			writelog("Zablokowany port $ports na switchu $hostname");
		}
		elsif ("$choice" == '2') {
			rblock ( 1 );
			print "Odblokowano: $hostname:\t $PORT \n";
			writelog("Odblokowany port $ports na switchu $hostname");
		}
		elsif ("$choice" == '3') {
			print "Podaj nr portu: ";
			chomp ($PORT = <STDIN>);
			print "Podaj jak chcesz nazwać port: \n";
			chomp ($names = <STDIN>);
	
			my $oid = $name.$PORT;
			rset($oid, OCTET_STRING, $names);
			print "Nowa nazwa dla portu $PORT: $names  \n";
			writelog("Zmieniona nazwa dla portu $PORT na switchu $hostname na $names");
		}
	}

	elsif ( "$whats" == '2' ) {
		print "Wybierz co chcesz zrobić: \n\t1) Zmienić dane kontaktowe \n\t2) Zmienić inne parametry switcha <- nie działa \n";
		$what = <STDIN>;
		if ($what == "0" ) {exit;}

		elsif ($what == '1') {
			print "Wybierz co chcesz zrobić: \n\t1) Ustawić nazwę switcha \n\t2) Zmienić lokalizacje switcha - w którym DS się znajduje \n\t3) Zmienić adres kontaktowy email \n";
			$choice = <STDIN>;
			if ($choice == "0" ) {exit;}

			if ("$choice" == '1') {
				rget( $name );
				print "Aktualna nazwa dla switcha: ".$res ." \n";

				print "Czy na pewno chcesz zmienić nazwę? (y/n)\n";
				chomp ($choice = <STDIN>);
		
				if ($choice eq "y") {
					print "Podaj nową nazwę dla switcha: \n";
					chomp ($newname = <STDIN>);

					my $re = snmpConnect($hostname, 'Admin-Community')->set_request( $sysname, OCTET_STRING, $newname ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
					print "Nowa nazwa: $newname \n";
					writelog("Ustawiona nową nazwę: $newname na switchu: $hostname");
				}
			}	
			elsif ("$choice" == '2') {
				rget( $location );
				print "Aktualna położenie: ".$res ." \n";
	
				print "Czy na pewno chcesz zmienić miejsce położenia? (y/n)\n";
				chomp ($choice = <STDIN>);
		
				if ($choice eq "y") {
					print "Podaj nowe miejsce położenia: \n";
					chomp ($newname = <STDIN>);

					my $re = snmpConnect($hostname, 'Admin-Community')->set_request( $location, OCTET_STRING, $newname ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
					print "Nowa lokalizacja: $newname \n";
					writelog("Ustawino nowa lokalizację: $newname na switchu $hostname");
				}
			}
			elsif ("$choice" == '3') {
				rget( $contact );
				print "Aktualna adres kontaktowy email: ".$res ." \n";

				print "Czy na pewno chcesz zmienić adres kontaktowy? (y/n)\n\a";
				chomp ($choice = <STDIN>);
		
				if ($choice eq "y") {
					print "Nowy adres email ('adnet\@ds.pg.gda.pl'): \n";
					$newname = 'adnet\@ds.pg.gda.pl';

					my $re = snmpConnect($hostname, 'Admin-Community')->set_request( $contact, OCTET_STRING, $newname ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
					writelog("Ustawiono nowy adres kontaktowy: $newname na switchu $hostname");
				}
			} else {
			print "Nie masz uprawnień do tej opcji!!! \n";
			writelog("Próba konfiguracji");
			}
		}
	}

        elsif ( "$whats" == '3' ) {
                print "Wybierz co chcesz zrobić: \n\t1) Sprawdziź lockout-mac \n\t2) lockout-mac \n\t3) no lockout-mac \n";
                $choice = <STDIN>;
		if ($choice == "0" ) {exit;}
		
		elsif ("$choice" == '1') {
		hostname;
			my $re = `snmpwalk -v 2c -c 'public-Community' $hostname $lockout | cut -d . -f10,11,12,13,14,15`;
			chomp($re);
			@res = split('\n', $re);

			foreach $mac (@res) {
				mac2int($mac, 16);
#                      		print "Lockout-mac na switchu $hostname:". split("."/":", $outmac) ."\n";
                      		print "Lockout-mac na switchu $hostname: $outmac \n";
			}
		}
                elsif ("$choice" == '2') {
			lockoutmac(3);
                        print "Lockout-mac dla adresu: $address na switchu $hostname \n";
			writelog("Lockout-mac dla adresu: $address na switchu $hostname");
		}
		elsif ("$choice" == 3) {
			lockoutmac(2);
                        print "No lockout-mac dla adresu: $address na switchu $hostname \n";
                        writelog("No lockout-mac dla adresu: $address na switchu $hostname");
		}
	}
}

if ( "$what" == '4' ) {
	print "Opcja niedostępna!!! \n";
}

if ( "$what" == '5' ) {
	print "Wybierz co chcesz zrobić: \n\t1) Sprawdzić dostępne VLANy i nazwy \n\t2) Ustawić nazwę dla VLANu - ustawienia wg standardów w SKOSie \n\t3) Dodać VLAN - ustawienia wg standardów w SKOSie \n\t4) Usuń dostępne VLANy \n";
        $choice = <STDIN>;
	if ($choice == "0" ) {exit;}
	
	elsif ("$choice" == '1') {
		hostname;
		my $re2 = `snmpwalk -v 2c -c 'public-Community' $hostname $vlan | cut -d . -f9`;
		chomp($re2); $re2 =~ s/STRING: //g;
		print "VLANy na switchu $hostname: \n\nID\tNazwa\n"; print $re2."\n";
	}
	elsif (("$choice" == '2') || ("$choice" == '3')) {
		print "Wybierz VLAN, który chcesz nazwać/ustawić: \n";
		print "\t1) 1 - DEFAULT_VLAN\n";
		print "\t2) 2 - VOIP\n";
		print "\t3) 20 - ADM\n";
		print "\t4) 30 - organ\n";
		print "\t5) 40 - users\n";
		print "\t6) 1000 - swadm\n";
		print "\t7) 1100 - ABUSERS\n";
		print "\t8) Inny - VLANid, Nazwa\n";
		chown($whats=<STDIN>);

		if ( "$choice" == '2')	{
			if ( "$whats" == '1' ) { $names = 'DEFAULT_VLAN'; $vlanid = '.1'; } elsif ("$whats" == '2') { $names = 'VOIP'; $vlanid = '.2'; } elsif ("$whats" == '3') { $names = 'ADM'; $vlanid = '.20'; } elsif ("$whats" == '4') { $names = 'organ'; $vlanid = '.30'; } elsif ("$whats" == '5') { $names = 'users'; $vlanid = '.40';  } elsif ("$whats" == '6') { $names = 'swadm'; $vlanid = '.1000'; } elsif ("$whats" == '7') { $names = 'ABUSERS'; $vlanid = '.1100'; } 
			elsif ( "$whats" == '8') { 
			print "Podaj VLANid: "; chomp($vlanid = <STDIN>); $vlanid = ".".$vlanid;
			print "Podaj Nazwę dla VLANu: "; chomp($names = <STDIN>); 
			}

			$oid = $vlan.$vlanid;
			hostname;
			my $ren = snmpConnect($hostname, 'Admin-Community')->set_request( $oid, OCTET_STRING, $names ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
			print "Ustawiono nazwę dla VLANu $vlanid na switchu $hostname na: $names \n";
			writelog("Ustawiono nazwę dla VLANu $vlanid na switchu $hostname na: $names");
		}
		elsif ( "$choice" == '3') {
			my $vlanid = shift;
			if ( "$whats" == '1' ) { $names = 'DEFAULT_VLAN'; $vlanid = '.1'; } elsif ("$whats" == '2') { $names = 'VOIP'; $vlanid = '.2'; } elsif ("$whats" == '3') { $names = 'ADM'; $vlanid = '.20'; } elsif ("$whats" == '4') { $names = 'organ'; $vlanid = '.30'; } elsif ("$whats" == '5') { $names = 'users'; $vlanid = '.40';  } elsif ("$whats" == '6') { $names = 'swadm'; $vlanid = '.1000'; } elsif ("$whats" == '7') { $names = 'ABUSERS'; $vlanid = '.1100'; } 
			elsif ( "$whats" == '8') {
			print "Podaj VLANid: "; chomp($vlanid = <STDIN>); $vlanid = ".".$vlanid;
			print "Podaj Nazwę dla VLANu: "; chomp($names = <STDIN>); 
			}

			$oid1 = $vlans.$vlanid;
			$oid2 = $vlan.$vlanid;
			hostname;
			my $rev = snmpConnect($hostname, 'Admin-Community')->set_request( $oid1, INTEGER, 4) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
			my $ren = snmpConnect($hostname, 'Admin-Community')->set_request( $oid2, OCTET_STRING, $names ) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
			print "Dodano nowy VLAN $vlanid na switchu $hostname z nazwą $names \n";
			writelog("Dodano nowy VLAN $vlanid na switchu $hostname z nazwą $names");
		}
	}
	elsif ("$choice" == '4') {
		hostname;
		my $re2 = `snmpwalk -v 2c -c 'public-Community' $hostname $vlan | cut -d . -f9`;
		chomp($re2); $re2 =~ s/STRING: //g;
		print "Dostępne VLANy: \n\nID\t NAZWA\n".$re2."\n";
		
		print "Czy na pewno chcesz usunąć VLANy? (y/n)\n\a";
		chomp ($choice = <STDIN>);
		
		if ($choice eq "y") {
			print "Podaj ID VLANu do usunięcia: ";
			chomp($vlanid = <STDIN>);
			$oid = $vlans.".".$vlanid;
			my $re = snmpConnect($hostname, 'Admin-Community')->set_request( $oid, INTEGER, 6) or print "Nie można się połączyć do switcha! Podałeś prawidłowe IP? \n";
			print "Usunięto VLAN $vlanid ze switcha $hostname \n";
			writelog("Usunięto VLAN $vlanid ze switcha $hostname \n");
		}
	}
}

if ( "$what" == '6' ) {
	print "Opcja niedostępna!!! \n";
}

if ( "$what" == '7' ) {
	reboot;
}

if($logging == 1) {
        close(LOGFILE);
}

undef $repeat;
	until ((lc ($repeat) eq "y") || (lc ($repeat) eq "n")) {
		print "\nChcesz kontynuować? (y/n): ";
		chomp ($repeat = <STDIN>);
	}
}
