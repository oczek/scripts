#!/usr/bin/perl
use Net::MAC;

my $mac = Net::MAC->new('mac' => '08:20:00:AB:CD:EF'); 

my $dec_mac = $mac->convert(
        'base' => 10,
        'bit_group' => 8,
        'delimiter' => '.'   
); 

print $dec_mac->get_mac(), "\n"; 

my $base = $mac->get_base();
if ($base == 16) { 
        print $mac->get_mac(), "hex format\n"; 
} 
elsif ($base == 10) { 
        print $mac->get_mac(), "dec format\n"; 
}
else { die "MAC is invalid"; } 
