#!/usr/bin/perl -w
use strict;

our $data;
my $filename = "timig_rpt.txt";  
open(my $fh, '<', $filename) or die "Could not open file '$filename' $!";  
	while (my $row = <$fh>) {  
 		$data = $row;
	}    

#print "$data\n";
#print "The report has been extracted to a variable.\n";

our $freq;
if ($data =~ /Computed maximum clock frequency/) {
	$freq = $data =~ /Computed maximum clock frequency(.*)hz/;
	print "The Computed maximum clock frequency is: $freq\n";}
else {
	print "Computed maximum clock frequency isn't avaiable in the report.\n";}	

