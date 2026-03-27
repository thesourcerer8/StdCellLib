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

sub vname
{
  my $n = shift;
  $n =~ s/^(\d+)$/net_$1/;
  return $n;
}

our %errorseen=();
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
    # Reset todo for next iteration to check ALL conducting transistors against updated voltages
    @todo=@lines; 
    $done=1 if(!$hadwork); # Should be redundant due to 'last'
  }

  verb "Results: "; verb "$_=$iv{$_} " foreach(sort keys %iv); verb "\n";

  $iv{$_}=~s/vdd/1/i foreach(keys %iv);
  $iv{$_}=~s/gnd/0/i foreach(keys %iv);

  return %iv;
}

sub analyze_sequential {
    my ($sccs_ref, $state_nets_ref, $orig_ins_ref, $ins_ref, $state_table_ref, $outs_ref) = @_;
    my @orig_ins = @$orig_ins_ref;
    my @ins = @$ins_ref;
    my @outs = @$outs_ref;
    my %st = %$state_table_ref;

    my @seq_outs = grep { my $o = $_; grep { my $s = $_; grep { $_ eq $o } @$s } @$sccs_ref } @outs;
    
    # Try to find a specific sequence for the FIRST sequential output (usually there's only one primary Q)
    foreach my $q (@seq_outs) {
        my $q_idx = -1; foreach my $i (0..$#ins) { $q_idx = $i if $ins[$i] eq $q; }
        next if $q_idx == -1;

        foreach my $p_name (@orig_ins) {
            my $p_idx = -1; foreach my $i (0..$#ins) { $p_idx = $i if $ins[$i] eq $p_name; }
            
            # Check for LATCH behavior on Q
            my $is_en_h = 1; my $is_en_l = 1;
            foreach my $gray (keys %{$st{$q}}) {
                my $p_val = ($gray >> $p_idx) & 1;
                my $q_prev = ($gray >> $q_idx) & 1;
                my $q_next = $st{$q}{$gray};
                next if $q_next eq "HIGH-Z";
                if ($p_val == 0 && $q_next != $q_prev) { $is_en_h = 0; }
                if ($p_val == 1 && $q_next != $q_prev) { $is_en_l = 0; }
            }
            if ($is_en_h || $is_en_l) {
                # Found Latch behavior! Now find D input.
                my $en_val = $is_en_h ? 1 : 0;
                my $d_pin = ""; my $d_inv = 0;
                foreach my $test_d (@orig_ins) {
                    next if $test_d eq $p_name;
                    my $t_idx = -1; foreach my $i (0..$#ins) { $t_idx = $i if $ins[$i] eq $test_d; }
                    my $matches = 0; my $mismatches = 0; my $total = 0;
                    foreach my $gray (keys %{$st{$q}}) {
                        next if (($gray >> $p_idx) & 1) != $en_val;
                        my $val = ($gray >> $t_idx) & 1;
                        if ($st{$q}{$gray} eq $val) { $matches++; } else { $mismatches++; }
                        $total++;
                    }
                    if ($total > 0 && $matches == $total) { $d_pin = vname($test_d); $d_inv = 0; last; }
                    if ($total > 0 && $mismatches == $total) { $d_pin = vname($test_d); $d_inv = 1; last; }
                }
                if ($d_pin) {
                    return { type => 'latch', enable => vname($p_name).($en_val?"":"'"), q => vname($q), d => ($d_inv ? "!$d_pin" : "$d_pin") };
                }
            }
            
            # Check for Flip-Flop behavior
            # For FF, we look for a internal "master" SCC such that Q follows it on clock edge
            foreach my $m_scc_ref (@$sccs_ref) {
                # Skip if it's the same SCC as Q
                next if grep { $_ eq $q } @$m_scc_ref;
                # Try every node in master SCC as potential M
                foreach my $m (@$m_scc_ref) {
                    my $m_idx = -1; foreach my $i (0..$#ins) { $m_idx = $i if $ins[$i] eq $m; }
                    next if $m_idx == -1;

                    my $is_pos = 1; my $is_neg = 1; 
                    my $is_inv_pos = -1; my $is_inv_neg = -1;
                    foreach my $gray (keys %{$st{$q}}) {
                        my $p_val = ($gray >> $p_idx) & 1;
                        my $m_prev = ($gray >> $m_idx) & 1;
                        my $q_prev = ($gray >> $q_idx) & 1;
                        my $q_next = $st{$q}{$gray};
                        next if $q_next eq "HIGH-Z";
                        # POS: CLK=1 -> Q transparent (follows M_prev), CLK=0 -> Q holds
                        if ($p_val == 1) {
                            if ($is_inv_pos == -1) { $is_inv_pos = ($q_next == (1-$m_prev)) ? 1 : 0; }
                            elsif ($is_inv_pos == 0 && $q_next != $m_prev) { $is_pos = 0; }
                            elsif ($is_inv_pos == 1 && $q_next == $m_prev) { $is_pos = 0; }
                            # For NEG, CLK=1 should hold
                            if ($q_next != $q_prev) { $is_neg = 0; }
                        } else { 
                            # For POS, CLK=0 should hold
                            if ($q_next != $q_prev) { $is_pos = 0; }
                            # NEG: CLK=0 -> Q transparent (follows M_prev)
                            if ($is_inv_neg == -1) { $is_inv_neg = ($q_next == (1-$m_prev)) ? 1 : 0; }
                            elsif ($is_inv_neg == 0 && $q_next != $m_prev) { $is_neg = 0; }
                            elsif ($is_inv_neg == 1 && $q_next == $m_prev) { $is_neg = 0; }
                        }
                    }
                    if ($is_pos) {
                        # Now find D for master M when CLK=0
                        my $d_pin = ""; my $d_inv = 0;
                        foreach my $test_d (@orig_ins) {
                            next if $test_d eq $p_name;
                            my $t_idx = -1; foreach my $i (0..$#ins) { $t_idx = $i if $ins[$i] eq $test_d; }
                            my $matches = 0; my $mismatches = 0; my $total = 0;
                            foreach my $gray (keys %{$st{$m}}) {
                                next if (($gray >> $p_idx) & 1) != 0;
                                my $val = ($gray >> $t_idx) & 1;
                                if ($st{$m}{$gray} eq $val) { $matches++; } else { $mismatches++; }
                                $total++;
                            }
                            if ($total > 0 && $matches == $total) { $d_pin = vname($test_d); $d_inv = $is_inv_pos; last; }
                            if ($total > 0 && $mismatches == $total) { $d_pin = vname($test_d); $d_inv = 1 - $is_inv_pos; last; }
                        }
                        if ($d_pin) {
                            return { type => 'ff', clocked_on => vname($p_name), q => vname($q), d => ($d_inv ? "!$d_pin" : "$d_pin") };
                        }
                    }
                    if ($is_neg) {
                        # Now find D for master M when CLK=1
                        my $d_pin = ""; my $d_inv = 0;
                        foreach my $test_d (@orig_ins) {
                            next if $test_d eq $p_name;
                            my $t_idx = -1; foreach my $i (0..$#ins) { $t_idx = $i if $ins[$i] eq $test_d; }
                            my $matches = 0; my $mismatches = 0; my $total = 0;
                            foreach my $gray (keys %{$st{$m}}) {
                                next if (($gray >> $p_idx) & 1) != 1;
                                my $val = ($gray >> $t_idx) & 1;
                                if ($st{$m}{$gray} eq $val) { $matches++; } else { $mismatches++; }
                                $total++;
                            }
                            if ($total > 0 && $matches == $total) { $d_pin = vname($test_d); $d_inv = $is_inv_neg; last; }
                            if ($total > 0 && $mismatches == $total) { $d_pin = vname($test_d); $d_inv = 1 - $is_inv_neg; last; }
                        }
                        if ($d_pin) {
                            return { type => 'ff', clocked_on => "!".vname($p_name), q => vname($q), d => ($d_inv ? "!$d_pin" : "$d_pin") };
                        }
                    }

                }
            }
        }
    }
    return { type => 'statetable' };
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
    verb "Analyzing $file\n";
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

    # AUTOMATIC SEQUENTIAL DETECTION: Find feedback cycles and pick minimal state nets
    my %net_to_scc = ();
    my @sccs = ();
    foreach my $start (sort keys %adj)
    {
      next if defined $net_to_scc{$start};
      my %reachable = ();
      my @queue = ($start);
      while (@queue) {
        my $curr = shift @queue;
        next if $reachable{$curr};
        $reachable{$curr} = 1;
        push @queue, map { $_->[0] } @{$adj{$curr} || []};
      }
      
      my %back_reachable = ();
      @queue = ($start);
      while (@queue) {
        my $curr = shift @queue;
        next if $back_reachable{$curr};
        $back_reachable{$curr} = 1;
        # For back-reachability, we check who has $curr as an adjacency
        foreach my $node (keys %adj) {
          foreach my $edge (@{$adj{$node}}) {
            push @queue, $node if $edge->[0] eq $curr;
          }
        }
      }
      
      my @scc = grep { $back_reachable{$_} } keys %reachable;
      if (scalar(@scc) > 1 || (scalar(@scc) == 1 && grep { $_->[0] eq $start && $_->[1] } @{$adj{$start} || []})) {
        # Valid SCC found. Is it actually sequential? (Must have at least one gate edge)
        my $seq = 0;
        foreach my $u (@scc) {
          foreach my $edge (@{$adj{$u}}) {
             $seq = 1 if $edge->[1] && grep { $_ eq $edge->[0] } @scc;
          }
        }
        if ($seq) {
          push @sccs, \@scc;
          $net_to_scc{$_} = $#sccs foreach @scc;
        }
      }
    }

    my @state_nets = ();
    my %is_out = map { $_ => 1 } @outs;
    foreach my $scc_ref (@sccs) {
      my %in_scc = map { $_ => 1 } @$scc_ref;
      # Count how many gate-edges each node drives toward other in-SCC nodes.
      # This identifies true state-holding nodes (inverter outputs, not transmission gate wires).
      my %gate_fanout = ();
      foreach my $n (@$scc_ref) {
        $gate_fanout{$n} = scalar(grep { $_->[1] && $in_scc{$_->[0]} } @{$adj{$n} || []});
      }
      my @sorted_scc = sort { 
         ($is_out{$b} || 0) <=> ($is_out{$a} || 0) ||
         ($gate_fanout{$b} || 0) <=> ($gate_fanout{$a} || 0) ||
         $a cmp $b 
      } @$scc_ref;
      push @state_nets, $sorted_scc[0];
    }

    if (@state_nets)
    {
       verb "Sequential behavior detected. State nets: ".join(", ", map { @$_ } @sccs)."\n";
       my %known_ins = map { $_ => 1 } @ins;
       foreach my $s (@state_nets) {
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

    our @nets_to_analyze = @outs;
    if ($format eq "verilog")
    {
       my %seen_nets = map { $_ => 1 } @outs;
       my %skip_nets = map { $_ => 1 } @original_ins;
       foreach my $s (@ins)
       {
         next if $skip_nets{$s} || $seen_nets{$s};
         push @nets_to_analyze, $s;
         $seen_nets{$s} = 1;
       }
    }

    foreach my $a(@ins)
    {
      if($a=~m/_n$/)
      {
        my $b=$a; $b=~s/_n$/_p/;
        if(defined($inputs{$b}))
	{
          $differential{$a}=$b;
	        verb "Differential input detected: $a <-> $b\n";
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
    elsif($format eq "liberty")
    {
      print "cell ($cellname) {\n";
      foreach my $in (@original_ins)
      {
         print "  pin(".vname($in).") {\n    direction: input;\n  }\n";
      }
    }
    elsif($format eq "verilog")
    {
      my %orig_in_set = map { $_ => 1 } @original_ins;
      my %out_set = map { $_ => 1 } @outs;
      print "module $cellname (\n";
      print "  input " . join(", ", map { vname($_) } @original_ins) . ",\n";
      print "  output " . join(", ", map { vname($_) } @outs) . "\n";
      print ");\n\n";

      # Declare internal state nets as wires
      foreach my $s (@ins)
      {
        next if $orig_in_set{$s} || $out_set{$s};
        print "  wire ".vname($s).";\n";
      }
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
    our %state_table=();
    my $statetable_rows = "";
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
        $output.="".($gray&(1<<$_))?"1 ":"0 " if($format eq "text" || $format eq "latex" || $format eq "html");
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
      my %res;
      eval { %res = truth(\@lines,\%values, \%strong_inputs); };
      if ($@) {
        verb "Skipping invalid state combination: $@";
        next;
      }
      foreach my $scc_ref (@sccs) {
          foreach (@$scc_ref) { $state_table{$_}{$gray} = $res{$_}; }
      }
      # The result is a hash with the intermediate/output netnames as keys and the resulting values as values
     
      # Now we are analyzing the results

    foreach my $out (@nets_to_analyze)
      {
	if(!defined($res{$out}))
        {
          $res{$out}="HIGH-Z";
          $highz_seen = 1;
        }
        $sum{$out}{$res{$out}}++; # We are counting the occurance of all output values of the whole truthtable to decide, which value is more often used, which helps to decide whether the function can be represented in a shorter way with a negation
	my @a=();
        my $not_char = ($format eq "verilog") ? "~" : "!";
	foreach(@ins)
	{
          my $name = ($format eq "verilog" || $format eq "liberty") ? vname($_) : $_;
          push @a,$res{$_}?"$name":"($not_char$name)"; # Here we are collecting all values for a AO representation
	}
        my $and_sep = ($format eq "liberty" || $format eq "verilog") ? " & " : " && ";
	push @{$results{$out}{$res{$out}}},join($and_sep, @a); # Here the single values are put together: (A && !B && C)   "Sum-of-Product"


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

      if ($format eq "liberty" && @state_nets)
      {
        my @in_vals = ();
        foreach (@original_ins) { push @in_vals, $values{$_} ? "H" : "L"; }
        my @state_vals = ();
        foreach (@state_nets) { push @state_vals, $values{$_} ? "H" : "L"; }
        my @next_vals = ();
        foreach (@state_nets) { push @next_vals, $res{$_} ? "H" : "L"; }
        $statetable_rows .= "           " . join(" ", @in_vals) . " : " . join(" ", @state_vals) . " : " . join(" ", @next_vals) . " ,\\\n";
      }

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
    if ($format eq "liberty" && @state_nets)
    {
      my $seq = analyze_sequential(\@sccs, \@state_nets, \@original_ins, \@ins, \%state_table, \@outs);
      if ($seq->{type} eq 'latch')
      {
         # Special LATCH group
         print "  latch (IQ_".vname($seq->{q}).", IQN_".vname($seq->{q}).") {\n";
         print "    enable : \"$seq->{enable}\" ;\n";
         print "    data_in : \"$seq->{d}\" ;\n";
         print "  }\n";
      }
      elsif ($seq->{type} eq 'ff')
      {
         # Special FF group
         print "  ff (IQ_".vname($seq->{q}).", IQN_".vname($seq->{q}).") {\n";
         print "    clocked_on : \"$seq->{clocked_on}\" ;\n";
         print "    next_state : \"$seq->{d}\" ;\n";
         print "  }\n";
      }
      else
      {
        # Fallback to STATETABLE
        my $in_names = join(" ", map { vname($_) } @original_ins);
        my $next_names = join(" ", map { "IQ_".vname($_) } @state_nets);
        $statetable_rows =~ s/ ,\\\n$/ /; # Fix trailing comma
        print "  statetable (\"$in_names\", \"$next_names\") {\n";
        print "    table : \"$statetable_rows\" ;\n";
        print "  }\n";
      }
    }

    foreach my $out (@nets_to_analyze) # We might have more than one output of a cell
    {

      # Finally checking whether we can compress the function for AOI/OAI here:
      my $npos=0;
      my @newinputs=();
      my %lookup=();
      my $aoioaifound=0;

      my $is_state = 0;
      my $is_primary_state = 0;
      if ($format eq "liberty" && @state_nets) {
          my $seq = analyze_sequential(\@sccs, \@state_nets, \@original_ins, \@ins, \%state_table, \@outs);
          if (($seq->{type} eq 'latch' || $seq->{type} eq 'ff') && vname($out) eq $seq->{q}) {
              $is_state = 1;
              $is_primary_state = 1;
          } elsif (grep { $_ eq $out } @state_nets) {
              $is_state = 1;
          }
      }

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
        delete $results{$out};

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
            $output.="".($gray&(1<<$_))?"1 ":"0 " if($format eq "text" || $format eq "latex" || $format eq "html");
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
          my %newres;
          eval { %newres = truth(\@lines,\%values, \%strong_inputs); };
          if ($@) { next; }

          verb "# Now we are analyzing the results\n";
	  #foreach my $out (@outs) # We already have a $out from the outer loop
	  #{
            $newres{$out}="HIGH-Z" if(!defined($newres{$out}));
            $newsum{$out}{$newres{$out}}++; # We are counting the occurance of all output values of the whole truthtable to decide, which value is more often used, which helps to decide whether the function can be represented in a shorter way with a negation
            my @a = ();
            my $not_char = ($format eq "verilog") ? "~" : "!";
            my %out_set = (map { $_ => 1 } @outs);
            foreach(@newinputs)
            {
              my $name = ($format eq "verilog" || $format eq "liberty") ? vname($_) : $_;
              push @a,$newres{$onepart{$_}}?"($name)":"($not_char($name))"; # Here we are collecting all values for a AO representation
            }
            my $and_sep = ($format eq "liberty" || $format eq "verilog") ? " & " : " && ";
            push @{$results{$out}{$newres{$out}}},join($and_sep, @a); # Here the single values are put together: (A && !B && C)   "Sum-of-Product"
          #} 
	  #print "\@a: ".join("&",@a)."\n";


	}
        my $not=($newsum{$out}{0}||0)>($newsum{$out}{1}||0)?1:0;
        # If we have more 0 than 1 results, then the negated inverse is shorted: 
        # TODO: When there are HIGH-Z outputs we should split the HIGH-Z outputs from the others and give a function for output-enable and HIGH-Z
        if($format eq "liberty")
        {
          print "  pin(".vname($out).") {\n    direction: output;\n";
          if ($is_state)
          {
            print "    function: \"IQ_".vname($out)."\";\n";
            print "    internal_node: \"IQ_".vname($out)."\";\n" unless $is_primary_state;
          }
          else
          {
            print "    function: \"";
          }
        }
        elsif($format eq "verilog")
        {
          print "  assign ".vname($out)." = ";
        }
        elsif($format eq "testcad")
        {
        }
        else
        {
          print "function: $out = ";
        }
        my @list=defined($results{$out}{$not})?@{$results{$out}{$not}}:();
        my $sep = ($format eq "liberty" || $format eq "verilog") ? " | " : " || ";
        if(!scalar(@list) || $is_state)
        {
        }
        elsif($not)
        {
          print "(".join($sep,@list).")";
        }
        else
        {
          my $not_op = ($format eq "verilog") ? "~" : "!";
          print "$not_op(".join($sep,@list).")";
        }

 

        # End of AOI/OAI checks
      }
      else
      {
        verb "DEBUG: Handle non-AOI/OAI for out='$out', format='$format'\n";
  
        my $not=($sum{$out}{0}||0)>($sum{$out}{1}||0)?1:0;
        # If we have more 0 than 1 results, then the negated inverse is shorted: 
        # TODO: When there are HIGH-Z outputs we should split the HIGH-Z outputs from the others and give a function for output-enable and HIGH-Z
        if($format eq "liberty")
        {
          print "  pin(".vname($out).") {\n    direction: output;\n";
          if ($is_state)
          {
            print "    function: \"IQ_".vname($out)."\";\n";
            print "    internal_node: \"IQ_".vname($out)."\";\n" unless $is_primary_state;
          }
          else
          {
            print "    function: \"";
          }
        }
        elsif($format eq "verilog")
        {
          print "  assign ".vname($out)." = ";
        }
        elsif($format eq "testcad")
        {
        }
        else
        {
          print "function: $out = ";
        }
        $is_state = ($format eq "liberty" && grep { $_ eq $out } @state_nets) ? 1 : $is_state;
        my @list=defined($results{$out}{$not})?@{$results{$out}{$not}}:();
        my $sep = ($format eq "liberty" || $format eq "verilog") ? " | " : " || ";
        if(!scalar(@list) || $is_state)
        {
          # No SOP for empty list or Liberty state pins (handled by statetable)
        }
        elsif($not)
        {
          print "(".join($sep,@list).")";
        }
        else
        {
          my $not_op = ($format eq "verilog") ? "~" : "!";
          print "$not_op(".join($sep,@list).")";
        }
  
      }
      if ($format eq "liberty")
      {
        print "\";\n" unless $is_state;
        print "  }\n";
      }
      print ";" if($format eq "verilog");
      print "\n";
      # TODO: We should try more functional representations like AOI, OAI, OR, NOR and see which one is the shortest representation
    }

    print "endmodule\n\n" if($format eq "verilog");
    print "}\n\n" if($format eq "liberty");
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
verb "WARNING: Potentially unresolved outputs (HIGH-Z) detected. This might indicate a design error.\n" if($highz_seen);
verb "Done.\n";


