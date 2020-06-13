#!/usr/bin/perl -w
use strict;
    
    
our $data;
print "Please enter the file name:\n";
my $file = <>; 
chomp $file;

	if ($file ne "sta_log.txt") 
		{
			print "File not found.\n";
		}

		else
		{

    			open(FH, $file) or die("File $file not found"); 
      
    			while(my $String = <FH>) 
    				{ 
        
					if($String =~ m/Computed maximum clock frequency (.*?)Hz/) 
        					{ 
	        					our $var = $1;												    #temp.
							our ($fin) = $var =~ m/(\d+\.\d+)/;     						#magnitude
							print "The computed maximum clock frequency is $var Hz\n"; 
							our $order = substr($var, -1);          						#exponential power
		
							if ($order eq "K")
								{
									my $opt = $fin * 1e-6;
									print ("The computed maximum clock frequency in giga hertz is $opt G Hz\n");
								}
		
							if ($order eq "M")
								{
									my $opt = $fin * 1e-3;
									print ("The computed maximum clock frequency in giga hertz is $opt G Hz\n");
								}
		
							if ($order eq "G")
								{
									my $opt = $fin;
									print ("The computed maximum clock frequency in giga hertz is $opt G Hz\n");
								}
							
							if ($order eq "T")
								{
									my $opt = $fin * 1e3;
									print ("The computed maximum clock frequency in giga hertz is $opt G Hz\n");
								}
        					} 
	
					else 
						{
							print "Computed maximum clock frequency isn't avaiable in the report.\n";	
						}
    				}
    
    			close(FH);
			
		}
