#!/usr/bin/perl -w
use strict;
use Getopt::Long;
use Data::Dumper;

# Commandine Parameters and their default values:
our $debug=0;
our $format="text"; # html latex text liberty verilog testcad

# Parsing the commandline parameters:
GetOptions ("debug" => \$debug,
	    "v" => \$debug,
            "format=s" => \$format);

our $highz_seen = 0;
our @original_ins = ();

our $testcadcounter=1; # counts the inputs, only needed for testcad output

# Convert a value to the gray code value:
sub bin2gray
{
  return $_[0] ^ ($_[0] >> 1);
}

sub verb # verbose debug output
{
  print $_[0] if($debug);
}

our %errorseen=();
sub myerror($) # prints error messages just once
{
  if(!defined($errorseen{$_[0]}))
  {
    print STDERR $_[0];
  }
  $errorseen{$_[0]}=1;
}

# Calculating the truth table for given netlist and input vectors
sub truth
{
  my @lines=@{$_[0]}; # lines from the netlist which contains transistors
  my %values=%{$_[1]}; # input values (input name -> input value)
  my %strong=%{$_[2]}; # New: strong input names

  verb "\nCalculating Truth table ...\n";

  my @todo=@lines; # Any transistors that have been switched and delivered a voltage already do not need to be tried again in the next step
  my %iv=%values; # input values
  my %iv_strong=%strong; # strong source flags
  foreach (keys %iv) { $iv_strong{$_}=1 if m/^(vdd|gnd)$/i; }
  $iv_strong{vdd}=1; $iv_strong{gnd}=1;

  my $done=0; # Are we done yet?
  my $hadwork=0; # Here we will remember whether any progress was made during a step

  while(!$done)
  {
    my @nexttodo=(); # Here we collect the transistors that we need to re-check in the next step
    $hadwork=0; # Did we succeed to flow the eletricity further in this step? If not, then we can stop since we can't make any more progress.
    foreach(@todo)
    {
      s/\s+$//m;
      verb "Line: $_\n";
      my @nets=();
      if(m/^res (\w+) (\w+) (\d+\.?\d*)/i) # We assume that resistors have a low resistance and pass the current
      {
        @nets=($1,$2);
      }
      elsif(m/^([pn]mos) (\w+) (\w+) (\w+)/i) # We are handling a Transistor here
      {
        my ($tr,$gate,$drain,$source)=($1,$2,$3,$4);
        verb "Transistor: $_\n";
        if(defined($iv{$gate}))
        {
          my $gatevalue=$iv{$gate}; $gatevalue=~s/vdd/1/i; $gatevalue=~s/gnd/0/i;
          my $conducting=$gatevalue ^ ($tr=~m/nmos/i ?0:1);
          if($conducting) { @nets=($drain,$source); }
          else { verb "Transistor not conducting\n"; next; }
        }
        else { verb "No information yet.\n"; push @nexttodo,$_; next; }
      }
      else { next; }

      # Propagate between @nets (e.g., Drain <-> Source)
      my ($n1, $n2) = @nets;
      my $i1=($n1=~m/^(vdd|gnd)$/i)?$n1:(defined($iv{$n1}) && $iv{$n1}=~m/^(vdd|gnd|0|1)$/i)?$iv{$n1}:undef;
      my $i1_strong = ($n1=~m/^(vdd|gnd)$/i || $iv_strong{$n1}) ? 1 : 0;
      my $i2=($n2=~m/^(vdd|gnd)$/i)?$n2:(defined($iv{$n2}) && $iv{$n2}=~m/^(vdd|gnd|0|1)$/i)?$iv{$n2}:undef;
      my $i2_strong = ($n2=~m/^(vdd|gnd)$/i || $iv_strong{$n2}) ? 1 : 0;

      if(defined($i1) && defined($i2))
      {
        my ($v1, $v2) = ($i1, $i2);
        $v1=~s/vdd/1/i; $v1=~s/gnd/0/i;
        $v2=~s/vdd/1/i; $v2=~s/gnd/0/i;
        if($v1 ne $v2 && $i1_strong && $i2_strong)
        {
          die "ERROR: Short circuit detected: $n1->$i1 $n2->$i2!\n";
        }
      }
      
      # Directional propagation
      if(defined($i1))
      {
        if(!defined($iv{$n2}) || ($iv{$n2} ne $i1 && $i1_strong && !$iv_strong{$n2}))
        {
          verb "Setting: $n2 <= $i1 (".($i1_strong?"strong":"weak").")\n";
          $iv{$n2}=$i1; $iv_strong{$n2}=$i1_strong; $hadwork=1;
        }
      }
      if(defined($i2))
      {
        if(!defined($iv{$n1}) || ($iv{$n1} ne $i2 && $i2_strong && !$iv_strong{$n1}))
        {
          verb "Setting: $n1 <= $i2 (".($i2_strong?"strong":"weak").")\n";
          $iv{$n1}=$i2; $iv_strong{$n1}=$i2_strong; $hadwork=1;
        }
      }
      push @nexttodo,$_ if((!defined($iv{$n1})) && (!defined($iv{$n2})));
    }
    if(!$hadwork)
    {
      verb "No further progress. Exiting.\n";
      last;
    }
    verb "Still to be done:\n@nexttodo\n\n";
    $done=1 if(!scalar(@nexttodo));
    @todo=@nexttodo;
  }

  verb "Results: "; verb "$_=$iv{$_} " foreach(sort keys %iv); verb "\n";

  $iv{$_}=~s/vdd/1/i foreach(keys %iv);
  $iv{$_}=~s/gnd/0/i foreach(keys %iv);

  return %iv;
}


if(!scalar(@ARGV)) # no parameters were given
{
  print "Calculates the truthtable for a given cell\n";
  print "Usage: truthtable.pl <filename.cell>\n";
}




# Take all the given filenames from the commandline
foreach my $file(@ARGV)
{
  my $cellname=$file; $cellname=~s/\.cell$//;

  # Open each file
  if(open(IN,"<$file"))
  {
    print STDERR "Analyzing $file\n" if($debug);
    my @lines=<IN>; # Read all lines into an array
    close IN;

    my %inputs=();
    my %intermediates=();
    my %outputs=();
    my %differential=();

    our %contact=();
    my %adj=();

    # Here we are parsing all transistor lines for input-, output- and intermediate nets
    # But this is just a guess:
    foreach(@lines)
    {
      next if(m/^#/); # Ignore comment lines
      #$differential{$1}=$2 if(m/^\.differential (\w+) (\w+)/);
      $inputs{$1}=1 if(m/^[pn]mos\s*([A-W]+\d*)/);
      $intermediates{$1}=1 if(m/^[pn]mos.*([X-Y]\w*\d*)/);
      $outputs{$1}=1 if(m/^[pn]mos.*\w+ ([X-Z]\w*\d*)/);
      if(m/^[pn]mos\s*(\w+) (\w+) (\w+)/i)
      {
        my ($g, $d, $s) = ($1, $2, $3);
        $contact{$2}{$1}=1;
        push @{$adj{$g}}, [$d, 1] unless $d =~ m/^(vdd|gnd)$/i;
        push @{$adj{$g}}, [$s, 1] unless $s =~ m/^(vdd|gnd)$/i;
        if($d !~ m/^(vdd|gnd)$/i && $s !~ m/^(vdd|gnd)$/i)
        {
          push @{$adj{$d}}, [$s, 0];
          push @{$adj{$s}}, [$d, 0];
        }
      }
    }
    delete($outputs{"Y"}) if(defined($outputs{"Z"})); # If we have Z, then Y is an internal net and Z is the output net

    our @ins=sort keys %inputs;
    our @outs=sort keys %outputs;
    our %insmap=();

    # Now we are parsing for the real inputs and ouputs if they are available
    foreach my $line(@lines)
    {
      @ins=split(" ",$1) if($line=~m/^\.inputs (\w.*)/i);
      @outs=split(" ",$1) if($line=~m/^\.outputs (\w.*)/i)
    }
    @original_ins = @ins;
    $inputs{$_}=1 foreach(@ins);

    # AUTOMATIC SEQUENTIAL DETECTION: Find feedback cycles
    my @state_nets = ();
    foreach my $start (keys %adj)
    {
      my %seen = ();
      my @queue = map { [$_->[0], $_->[1]] } @{$adj{$start} || []};
      my $is_sequential = 0;
      while (@queue)
      {
        my $item = shift @queue;
        my ($curr, $has_gate_edge) = @$item;
        if ($curr eq $start && $has_gate_edge) { $is_sequential = 1; last; }
        next if $seen{$curr}{$has_gate_edge};
        $seen{$curr}{$has_gate_edge} = 1;
        foreach my $next_item (@{$adj{$curr} || []})
        {
          push @queue, [$next_item->[0], $has_gate_edge || $next_item->[1]];
        }
      }
      push @state_nets, $start if ($is_sequential);
    }
    if (@state_nets)
    {
       print STDERR "Sequential behavior detected. State nets: ".join(", ", @state_nets)."\n" if ($debug);
       my %known_ins = map { $_ => 1 } @ins;
       foreach my $s (@state_nets)
       {
         push @ins, $s unless $known_ins{$s};
         $known_ins{$s} = 1;
       }
    }
    $inputs{$_}=1 foreach(@ins);

    # Now creating a reverse lookup map so that we can get the number of the input from the name:
    foreach my $i(0 .. scalar(@ins)-1)
    {
      $insmap{$ins[$i]}=$i;
    }

    foreach my $a(@ins)
    {
      if($a=~m/_n$/)
      {
        my $b=$a; $b=~s/_n$/_p/;
        if(defined($inputs{$b}))
	{
          $differential{$a}=$b;
	  #print STDERR "Differential input detected: $a <-> $b\n";
	}
      }
    }

    our %monitor=();
    our %isgood=();
    our %seen=();
    # Now we are analyzing the contacts of the transistor net to find potential candidates for AOI/OAI aggregations:
    foreach my $net(sort keys %contact)
    {
      my @contacts=sort keys %{$contact{$net}};
      verb "net $net: ".join(" ",@contacts)."\n";
      if(scalar(@contacts)==2 && defined($inputs{$contacts[0]}) && defined($inputs{$contacts[1]}))
      {
        verb "GOOD $contacts[0] $contacts[1]\n";	    
        $monitor{$contacts[0]}{$contacts[1]}=1;
	foreach my $out(@outs)
	{
          $isgood{$out}{$contacts[0]}{$contacts[1]}{"&"}=1;
          $isgood{$out}{$contacts[0]}{$contacts[1]}{"|"}=1;
	}
      }	  
    }


    my $ninputs=scalar(@ins);
    my $noutputs=scalar(@outs);
    my $combinations=2**$ninputs; # We calculate the number of possible combinations in the truthtable

    verb "Number of Inputs: $ninputs (".join(",",@ins).") -> Combinations: $combinations\n";
    verb "Number of Outputs: $noutputs (".join(",",@outs).")\n";

    if($ninputs<1)
    {
      die "ERROR: A cell without an input!\n";
    }

    # Now we start with the header of the output files:
    if($format eq "text")
    {
      print join(" ",@ins)."->".join(" ",@outs); print "\n";
    }
    elsif($format eq "latex")
    {
print <<EOF
%%  ************    LibreSilicon's StdCellLibrary   *******************
%%
%%  Organisation:   Chipforge
%%                  Germany / European Union
%%
%%  Profile:        Chipforge focus on fine System-on-Chip Cores in
%%                  Verilog HDL Code which are easy understandable and
%%                  adjustable. For further information see
%%                          www.chipforge.org
%%                  there are projects from small cores up to PCBs, too.
%%
%%  File:           StdCellLib/Documents/LaTeX/truthtable_$cellname.tex
%%
%%  Purpose:        Truth Table File for $cellname
%%
%%  ************    LaTeX with circdia.sty package      ***************
%%
%%  ///////////////////////////////////////////////////////////////////
%%
%%  Copyright (c) 2019 by chipforge <hsank\@nospam.chipforge.org>
%%  All rights reserved.
%%
%%      This Standard Cell Library is licensed under the Libre Silicon
%%      public license; you can redistribute it and/or modify it under
%%      the terms of the Libre Silicon public license as published by
%%      the Libre Silicon alliance, either version 1 of the License, or
%%      (at your option) any later version.
%%
%%      This design is distributed in the hope that it will be useful,
%%      but WITHOUT ANY WARRANTY; without even the implied warranty of
%%      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
%%      See the Libre Silicon Public License for more details.
%%
%%  ///////////////////////////////////////////////////////////////////

\\begin{center}
EOF
;

      print "    {\(Z = \\lnot ((B1 \\land B0) \\lor A) \\)}\n";
      print "    \\begin{table}[h] %\\caption{\\(Z = \\lnot ((B1 \\land B0) \\lor A) \\)}\n";
      print "        \\begin{center}\n";
      print "            \\begin{tabular}{";
      print "|c" foreach(@ins);
      print "|";
      print "|c" foreach(@outs);
      print "|} \\hline\n";
      print "            "; 
      print join(" & ",@ins)." & ".join(" & ",@outs)." \\\\ \\hline\\hline\n";
    }
    elsif($format eq "html")
    {
      print "<table border='1' class='truthtable'>\n<tr><th>".join("</th><th>",@ins)."</th><th><b>".join("</b></th><th><b>",@outs)."</b></th></tr>\n";
    }
    elsif($format eq "testcad")
    {
      foreach (@ins)
      {
        print "$testcadcounter PI ".($testcadcounter+1)." ; # $_\n";
	$testcadcounter+=2;
      }
    }

    my %values=();
    our %sum=();
    our %results=();
    # Now we calculate all the truth-table values:
    foreach my $i(0 .. 2**$ninputs-1)
    {
      # We count from 0 .. 2^n-1 and take the graycode, and then interpret that as a binary value for the input stimulus:
      my $output="";
      my $gray=bin2gray($i); 
      $output.="            " if($format eq "latex");
      $output.="<tr>" if($format eq "html");
      foreach(0 .. $ninputs-1)
      {
	$output.="& " if($format eq "latex" && $_>0);
        $output.="<td>" if($format eq "html");
        $output.="".($gray&(1<<$_))?"1 ":"0 " if($format eq "text" || $format eq "latex" || $format eq "html"); # not for liberty!
        $output.="</td>" if($format eq "html");
	$values{$ins[$_]}=($gray&(1<<$_))?1:0;
      }

      my $ignoreinvalidinputs=0; # Look for differential inputs that have the same value, and are therefore invalid
      foreach my $k1(keys %differential)
      {
        $ignoreinvalidinputs=1 if($values{$k1} eq $values{$differential{$k1}});
      }
      next if($ignoreinvalidinputs);

      print $output;

      # Here we are using the truth function to calculate all network states for the given inputs:
      my %strong_inputs = map { $_ => 1 } @original_ins;
      my %res=truth(\@lines,\%values, \%strong_inputs);
      # The result is a hash with the intermediate/output netnames as keys and the resulting values as values
     
      # Now we are analyzing the results
      foreach my $out (@outs)
      {
	if(!defined($res{$out}))
        {
          $res{$out}="HIGH-Z";
          $highz_seen = 1;
        }
        $sum{$out}{$res{$out}}++; # We are counting the occurance of all output values of the whole truthtable to decide, which value is more often used, which helps to decide whether the function can be represented in a shorter way with a negation
	my @a=();
	foreach(@ins)
	{
          push @a,$res{$_}?"$_":"(!$_)"; # Here we are collecting all values for a AO representation, e.g. (A && !B && C) || (!A && B && C))  "Sum-of-Product"
	}
	push @{$results{$out}{$res{$out}}},join($format eq "liberty"?"&":" && ",@a); # Here the single values are put together: (A && !B && C)   "Sum-of-Product"


        # Now we are specifically checking for AOI/OAI
        foreach my $first (sort keys %monitor)
        {
          foreach my $second (sort keys %{$monitor{$first}})
          {
            myerror("Error in $file: IO $first not found!\n") if(!defined($insmap{$first}));
            myerror("Error in $file: IO $second not found!\n") if(!defined($insmap{$second}));
            my $fn=$insmap{$first} || 0;
            my $sn=$insmap{$second} || 0;
            my $fv=$values{$first};
            my $sv=$values{$second};
	    verb "F:$first:$fv S:$second:$sv\n";
            my $and=$fv && $sv;
            my $or=$fv || $sv;
            my $rest="";
            foreach my $i(@ins) # 0 .. $ninputs-1)
            {
              verb "i:$i ninputs:$ninputs\n";
              $rest.=$values{$i}."*" unless($i eq $first || $i eq $second);
            }
            verb "fn:$fn fv:$fv sn:$sn sv:$sv and:$and or:$or rest:$rest\n";
            foreach my $op (("&:$and","|:$or"))
            {
              my $idx="$out $first $second $op $rest";
              my $wert=$res{$out};
              if(defined($seen{$idx}) && $seen{$idx} eq $wert)
              {
                verb "Still Good Pair: $first $second\n";
              }
              elsif(defined($seen{$idx}))
              {
                verb "Bad pair: out:$out $first $second $op (idx:$idx seen:$seen{$idx} exected:$wert)\n";
		#$isgood{$out}{$first}{$second}{substr($op,0,1)}=0;
                delete $isgood{$out}{$first}{$second}{substr($op,0,1)};
              }
              else
              {
                verb "Initial pair value: $wert\n";
                $seen{$idx}=$wert;
              }
            } # foreach $op
          } # foreach $second input
        } # foreach $first input
        # We are done with the AOI/OAI checks


      } # foreach $out outputs

      if($format eq "text")
      {
        print "$_=$res{$_} " foreach(@outs); 
      }
      elsif($format eq "latex")
      {
        print "& $res{$_} " foreach(@outs);
        print "\\\\ \\hline";
      }
      elsif($format eq "html")
      {
        print "<td><b>$res{$_}</b></td>" foreach(@outs);
      }
      print "</tr>" if($format eq "html");
      print "\n" if($format eq "text" || $format eq "html");

    } # foreach $i all input combinations

    print "</table>\n" if($format eq "html");


    foreach my $out (@outs) # We might have more than one output of a cell
    {

      # Finally checking whether we can compress the function for AOI/OAI here:
      my $npos=0;
      my @newinputs=();
      my %lookup=();
      my $aoioaifound=0;
      
      foreach my $first(sort keys %{$isgood{$out}})
      {
        foreach my $second(sort keys %{$isgood{$out}{$first}})
        {
          verb "AOI for out:$out first:$first second:$second\n";
          foreach my $op(sort keys %{$isgood{$out}{$first}{$second}})
          {
            #print "GOOD COMBINATION: out:$out $first $second $op\n"; # $isgood{$first}{$second}{$op}\n";
	    $aoioaifound=1;
            my $isfirst=defined($lookup{$first.$op});
            if($isfirst || defined($lookup{$second.$op}))
            {
              my $pos=$isfirst?$lookup{$first.$op}:$lookup{$second.$op};
              $newinputs[$pos].=$op.($isfirst?$second:$first);
              $lookup{$first.$op}=$pos;
              $lookup{$second.$op}=$pos;
            }
            else
            {
              #print "Adding new combo to position $npos\n";
              push @newinputs,"$first$op$second";
              $lookup{$first.$op}=$npos;
              $lookup{$second.$op}=$npos;
              $npos++;
            } 
          }
        }
      }
      if($aoioaifound) # we have found several inputs that are always and/or'ed for this particular output
      {
        verb "function: $out = AOI/OAI compressed: ";
        %results=();

        foreach(@ins)
        {
          if(!defined($lookup{$_."|"}) && !defined($lookup{$_."&"}))
          {
            push @newinputs,$_;
          }
        }
        foreach(@newinputs)
        {
          #print "($_) ";
        }
        #print "\n";

        my $nnewinputs=scalar(@newinputs);
        our %newsum=();

        foreach my $i(0 .. 2**$nnewinputs-1)
        {
          # We count from 0 .. 2^n-1 and take the graycode, and then interpret that as a binary value for the input stimulus:
          my $output="";
          my $gray=bin2gray($i); 
          $output.="            " if($format eq "latex");
          $output.="<tr>" if($format eq "html");
	  my %onepart=();
          foreach(0 .. $nnewinputs-1)
          {
            $output.="& " if($format eq "latex" && $_>0);
            $output.="<td>" if($format eq "html");
            $output.="".($gray&(1<<$_))?"1 ":"0 " if($format eq "text" || $format eq "latex" || $format eq "html"); # not for liberty!
            $output.="</td>" if($format eq "html");
	    if($newinputs[$_]=~m/[\&\|]/)
	    {
              foreach my $subname(split(/[\&\|]/,$newinputs[$_]))
	      {
		$onepart{$newinputs[$_]}=$subname;
                $values{$subname}=($gray&(1<<$_))?1:0;
	      }
	    }
	    else
	    {
              $onepart{$newinputs[$_]}=$newinputs[$_];
              $values{$newinputs[$_]}=($gray&(1<<$_))?1:0;
	    }
          }
    
          my $ignoreinvalidinputs=0; # Look for differential inputs that have the same value, and are therefore invalid
          foreach my $k1(keys %differential)
          {
            $ignoreinvalidinputs=1 if($values{$k1} eq $values{$differential{$k1}});
          }
          next if($ignoreinvalidinputs);
    
	  verb "# $output\n";
    
          # Here we are using the truth function to calculate all network states for the given inputs:
	  # TODO: What is better? Doing the digital simulation again or caching the results?
	  my %strong_inputs = map { $_ => 1 } @original_ins;
          my %newres=truth(\@lines,\%values, \%strong_inputs);

          verb "# Now we are analyzing the results\n";
	  #foreach my $out (@outs) # We already have a $out from the outer loop
	  #{
            $newres{$out}="HIGH-Z" if(!defined($newres{$out}));
            $newsum{$out}{$newres{$out}}++; # We are counting the occurance of all output values of the whole truthtable to decide, which value is more often used, which helps to decide whether the function can be represented in a shorter way with a negation
            my @a=();
            foreach(@newinputs)
            {
              push @a,$newres{$onepart{$_}}?"($_)":"(!($_))"; # Here we are collecting all values for a AO representation, e.g. (A && !B && C) || (!A && B && C))  "Sum-of-Product"
            }
            push @{$results{$out}{$newres{$out}}},join($format eq "liberty"?"&":" && ",@a); # Here the single values are put together: (A && !B && C)   "Sum-of-Product"
          #} 
	  #print "\@a: ".join("&",@a)."\n";


	}
        my $not=($newsum{$out}{0}||0)>($newsum{$out}{1}||0)?1:0;
        # If we have more 0 than 1 results, then the negated inverse is shorted: 
        # TODO: When there are HIGH-Z outputs we should split the HIGH-Z outputs from the others and give a function for output-enable and HIGH-Z
        if($format eq "liberty")
        {
          print "  pin($out) {\n    direction: output;\n    function:\"";
        }
        elsif($format eq "testcad")
        {
        }
        else
        {
          print "function: $out = ";
        }
        my @list=defined($results{$out}{$not})?@{$results{$out}{$not}}:();
        if(!scalar(@list))
        {
        }
        elsif($not)
        {
          print "(".join($format eq "liberty"?"|":" || ",@list).")";
        }
        else
        {
          print "!(".join($format eq "liberty"?"|":" || ",@list).")";
        }
 

        # End of AOI/OAI checks
      }
      else
      {
        verb "Handle non-AOI/OAI\n";
  
        my $not=($sum{$out}{0}||0)>($sum{$out}{1}||0)?1:0;
        # If we have more 0 than 1 results, then the negated inverse is shorted: 
        # TODO: When there are HIGH-Z outputs we should split the HIGH-Z outputs from the others and give a function for output-enable and HIGH-Z
        if($format eq "liberty")
        {
          print "  pin($out) {\n    direction: output;\n    function:\"";
        }
        elsif($format eq "testcad")
        {
        }
        else
        {
          print "function: $out = ";
        }
        my @list=defined($results{$out}{$not})?@{$results{$out}{$not}}:();
        if(!scalar(@list))
        {
        }
        elsif($not)
        {
          print "(".join($format eq "liberty"?"|":" || ",@list).")";
        }
        else
        {
          print "!(".join($format eq "liberty"?"|":" || ",@list).")";
        }
  
      }
      print $format eq "liberty" ? "\";\n  }":" ";
      print $format eq "verilog" ? "\n":"\n";
      # TODO: We should try more functional representations like AOI, OAI, OR, NOR and see which one is the shortest representation
    }

    print "\n" if($format eq "liberty");
    if($format eq "latex")
    {
      print <<EOF
            \\end{tabular}
        \\end{center}
    \\end{table}
\\end{center}
EOF
;
    }
  }
}
print STDERR "WARNING: Potentially unresolved outputs (HIGH-Z) detected. This might indicate a design error.\n" if($highz_seen);
print STDERR "Done.\n" if($debug);


