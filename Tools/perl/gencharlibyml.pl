#!/usr/bin/perl -w

# This tool is automatically used by the StdCellLib flow, it is called by librecells.pl
# If you want to run it manually, run it from the CATALOG directory and make sure that the PDK environment variable is set.

sub header()
{
  my $target_voltage=3.3;
  my $TARGETVOLTAGE=$ENV{'TARGETVOLTAGE'};
  if ($TARGETVOLTAGE =~ /^(\d+(\.\d+)?)V$/) {
    $target_voltage=$1;
  }

  print OUT <<EOF
settings:
    lib_name: libresilicon-$ENV{'PDK'}
    units:
        time:               ns
        voltage:            V
        current:            uA
        pulling_resistance: kOhm
        leakage_power:      nW
        capacitive_load:    pF
        energy:             fJ
    named_nodes:
        vdd:
            name:       VDD
            voltage:    $target_voltage
        vss1:
            name:       GND
            voltage:    0
        vss2:
            name:       VSS
            voltage:    0
        pwell:
            name:       VPW
            voltage:    0
        nwell:
            name:       VNW
            voltage:    $target_voltage
    cell_defaults:
        models:
EOF
;
# This is PDK dependent!
  print OUT <<EOF
            - ../Tech/transistors.ngspice typical # This syntax tells CharLib to use the '.lib file section' syntax for this model
            - ../Tech/design.ngspice
EOF
;
  print OUT <<EOF
        slews: [0.015, 0.04, 0.08, 0.2, 0.4]
        loads: [0.06, 0.18, 0.42, 0.6, 1.2]
cells:
EOF
;
}

my @cells=@ARGV;
@cells=<*.cell> if(!scalar(@cells));

if(scalar(@cells)>1) # If we have more than one cell we create one yml file for the whole library
{
  my $fn="libresilicon-charlib.yml";
  open OUT,">$fn";
  print "Writing to $fn\n";
  header();
}


foreach my $cell(@cells)
{
  my $cn=$cell; $cn=~s/\.cell$//;
  if(! -f "$cn.truthtable.v")
  {
    print "Skipping $cell due to missing truthtable\n";
    next;
  }
  print "Handling $cell\n";
  if(scalar(@cells)==1) # If we have only a single cell we create a yml file for that single cell
  {
    open OUT,">$cn.yml";
    print "Writing to $cn.yml\n";
    header();
  }
  open IN,"<$cell";
  print OUT "    $cn:\n";
  print OUT "        netlist: $cn.spice\n";
  while(<IN>)
  {
    if(/^\.inputs (.*?)\s*$/)
    {
      my $ins=$1; $ins=~s/ /,/g;
      print OUT "        inputs: [$ins]\n";
    }
    if(/^\.outputs (.*?)\s$/)
    {
      my $outs=$1; $outs=~s/ /,/g;
      print OUT "        outputs: [$outs]\n";
    }
  }
  close IN;

  if(open(IN,"<outputlib/$cn.lef"))
  {
    while(<IN>)
    {
      if(m/SIZE\s+(\d+\.?\d*)\s+BY\s+(\d+\.\d*)/)
      {
        my $area=int($1*$2*100);
	print OUT "        area: $area\n";
      }
    }
    close IN;
  }
  if(open(IN,"<$cn.truthtable.v"))
  {
    print OUT "        functions:\n";
    while(<IN>)
    {
      s/function: //; s/\&\&/\&/g; s/\|\|/\|/g; s/ //g; s/\!(\w+)/\(!$1\)/g;
      print OUT "            - $_";
    }
    close IN;
  }
  if(scalar(@cells)==1)
  {
    close OUT;
  }

}

if(scalar(@cells)>1)
{
  close OUT;
}
