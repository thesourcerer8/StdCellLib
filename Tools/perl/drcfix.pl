#!/usr/bin/perl -w
use File::Basename ();

if(scalar(@ARGV)<1)
{ 
  print "Usage: drcfix.pl problematic.mag [techfile.tech] [DRC rule deck]\n";
  exit;	
}

# Rules we have to deal with:

#Local interconnect spacing < 0.17um (LI 3)
#Metal1 spacing < 0.14um (Met1 2)

print "Handling $ARGV[0]\n";
open IN,"<".$ARGV[0];
my $mag=$ARGV[0];$mag=~s/\.drc$/.mag/; $mag=~s/\.mag\.mag/\.mag/;
my $output="corr_$mag";
my $tcl=$mag; $tcl=~s/\.mag$/.drc.tcl/;
my $mode=0;
my $try=1;
my $debug=1;

sub form($)
{
  return int($_[0]*100);
}

my $insert="";
our $tech=$ARGV[1] || "../Tech/libresilicon.tech";
our $drcstyle=$ARGV[2] || "";

#sub tryfix($)
#{
  print "Trying the fix on $mag:\nRuning magic ...\n";

  my $bindir = File::Basename::dirname($0);
  open IN,"<$bindir/drcfix.tcl";
  undef $/;
  $todo=<IN>;
  close IN;

  $todo=~s/\$OUTPUT/$output/sg;
  $todo=~s/\$MAG/$mag/sg;
  $todo=~s/\$DRCSTYLE/$drcstyle/sg;

if($debug)
{
  open OUT,">$tcl";
  print OUT $todo;
  close OUT;
  system "magic -dnull -rcfile $tcl -noconsole -T $tech";
}
else
{
  open OUT,"|magic -dnull -noconsole -nowindow -T $tech";
  print OUT $todo;
  close OUT;
}

#tryfix();

if(0)
{

while(<IN>)
{
  if(m/Mcon spacing < 0\.17um \(Mcon 2\)/)
  {
    $mode="viali";
    my $dummy=<IN>;
    print "Found my rule\n";
    next;
  }
  if(m/Diffusion contact spacing < 0.17um \(LIcon 2\)/)
  {
    $mode="ndiffc";
    my $dummy=<IN>;
    print "Found my rule\n";
    next;
  }
  if(m/Local interconnect spacing < 0.17um \(LI 3\)/)
  {
    $mode="li_spacing";
    my $dummy=<IN>;
    print "Found my rule\n";
    next;
  }

  if(m/\-\-\-\-\-\-\-\-\-\-\-/)
  {
    $mode=0;
    print "End of rule\n";
    next;
  }


  if($mode eq 1)
  {
    my @line1=split " ",$_;
    my $l2=<IN>;
    my @line2=split " ",$l2;
    print "LINE1 (@line1): $_\nLINE2 (@line2): $l2\n";
    if($line1[0] eq $line2[0] && $line1[2] eq $line2[2] && $line1[1]<$line2[1])
    {
      print "Vertikal\n";
      print "@line1 - @line2\n";
      $insert.="<< $mode >>\nrect ".form($line1[0])." ".form($line1[3])." ".form($line1[2])." ".form($line2[1])."\n";
    }
    elsif($line1[1] eq $line2[1] && $line1[3] eq $line2[3] && $line1[0]<$line2[0])
    {
      print "Horizontal\n";
      print "@line1 - @line2\n";
      $insert.="<< $mode >>\nrect ".form($line1[2])." ".form($line1[1])." ".form($line2[3])." ".form($line1[1])."\n";
    }

  }


  if($mode eq "li_spacing")
  {
    my @line1=split " ",$_;
    my $l2=<IN>;
    my @line2=split " ",$l2;
    print "LINE1 (@line1): $_\nLINE2 (@line2): $l2\n";
    #if($line1[0] eq $line2[0] && $line1[2] eq $line2[2] && $line1[1]<$line2[1])
    #{
    #  print "Vertikal\n";
    #  print "@line1 - @line2\n";
      tryfix("box position $line1[0] $line1[1]\nbox size $line2[0] $line2[1]\nerase li\n");
    #  $insert.="<< $mode >>\nrect ".form($line1[0])." ".form($line1[3])." ".form($line1[2])." ".form($line2[1])."\n";
    #}
    #elsif($line1[1] eq $line2[1] && $line1[3] eq $line2[3] && $line1[0]<$line2[0])
    #{
    #  print "Horizontal\n";
    #  print "@line1 - @line2\n";
    #  $insert.="<< $mode >>\nrect ".form($line1[2])." ".form($line1[1])." ".form($line2[3])." ".form($line1[1])."\n";
    #}

  }


}
close IN;

open MAG,"<$mag";
open CORR,">corr.$mag";
print "Reading from $mag Writing to corr.$mag\n";
while(<MAG>)
{
  if(m/<< end >>/)
  {	
    print CORR $insert;
  }
  print CORR $_;
}
close CORR;
close MAG;

}
