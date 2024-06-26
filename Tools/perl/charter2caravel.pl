#!/usr/bin/perl -w

my $doverification=1;
my $maxios=38+128-2; # How many IOs does one Caravel have?
my $maxdesigns=1; # How many Caravels do you want to use maximum?
our $githubuser=$ENV{'GITHUB_USER'} || "thesourcerer8"; # GitHub Username for the Repository URL
our $efablessuser=$ENV{'EFABLESS_USER'} || "philippguehring"; # EFabless GIT username
our $CARAVEL="";
our @repos=();
our %assigned=();
our $ngroups=0;
my $usedios=0;
my $totalios=0;
my $group=1;

print "Chartering one or more Caravels ...\n";

open IN,"<../Tech/caravel-env.sh";
print "Loading Caravel environment variables.\n";
while(<IN>)
{
  if(m/^export (\w+)="([^"]+)"/)
  {
    $ENV{$1}=$2;
    print "Setting Caravel variable $1 to $2\n";
  }
}
close IN;

my $magictech=$ENV{'PDK'} || "gf180mcuD"; # MAGIC Technology name (.tech filename)
$ENV{'PDK'}=$magictech;

sub getCellLibrary($)
{
  return "gf180mcu_fd_sc_mcu9t5v0" if($_[0]=~m/gf180/i);
  return "sky130_fd_sc_hd" if($_[0]=~m/sky130/i);
  return "";
}

my $celllibrary=getCellLibrary($ENV{'PDK'});

my $branch=$ENV{'CARAVEL_BRANCH'} || "gfmpw-1c"; # Git Branch for the Caravel User Project

sub system_v($)
{
  print "$_[0]\n";
  return system($_[0]);
}

sub step($)
{
  print "$_[0]\n";
  print STDERR "$_[0]\n";
}

sub nextgroup($)
{
  $CARAVEL="gf180_stdcelllib_$_[0]";
  $CARAVEL="sky130_stdcelllib_$_[0]" if($ENV{'PDK'}=~m/sky130/i);

  if($ngroups>=$maxdesigns)
  {
    print STDERR "Stopping at the defined limit of maximum $maxdesigns designs.\n";
    return(undef);
  }
  unless(-d $CARAVEL)
  {
    system_v "git clone git\@github.com:efabless/caravel_user_project.git -b $branch $CARAVEL";
    return(undef) unless(-d $CARAVEL);
  }
  push @repos,$CARAVEL;
  $ngroups++;
  return $CARAVEL;
}

sub addcell($$)
{
  my ($group,$cn)=@_;
  print "Adding cell $cn to group $group\n";
  $assigned{$CARAVEL}{$cn}=1;
  mkdir "$CARAVEL/cells";
  mkdir "$CARAVEL/cells/mag";
  mkdir "$CARAVEL/cells/lib";
  mkdir "$CARAVEL/cells/cell";
  mkdir "$CARAVEL/cells/sp";
  mkdir "$CARAVEL/cells/lef";
  mkdir "$CARAVEL/cells/lef/orig";
  mkdir "$CARAVEL/cells/gds";
  mkdir "$CARAVEL/cells/truthtable";
  system "cp $cn.mag $CARAVEL/cells/mag/";
  system "cp $cn.lib $CARAVEL/cells/lib/" if(-f "$cn.lib");
  system_v "perl ../Tools/perl/dummychar.pl $cn >$CARAVEL/cells/lib/$cn.lib" unless(-f "$cn.lib");
  system "cp $cn.cell $CARAVEL/cells/cell/";
  system "cp $cn.sp $CARAVEL/cells/sp/";
  system "cp $cn.truthtable.txt $CARAVEL/cells/truthtable/";
  system "cp outputlib/$cn.lef $CARAVEL/cells/lef/orig/";
  system "cp outputlib/$cn.gds $CARAVEL/cells/gds/";
}

sub endgroup($)
{
  my $CARAVEL=$_[0];

  #$ENV{'STD_CELL_LIBRARY'}='sky130_fd_sc_ls';
  $ENV{'STDCELLLIB'}='../'; # /home/philipp/libresilicon/StdCellLib
  $ENV{'OPENLANE_ROOT'}=$ENV{'PWD'}."/$CARAVEL/dependencies/openlane_src"; # =$(readlink -f $(pwd)/../openlane )
  #$ENV{'OPENLANE_TAG'}="gfmpw-0c";
  $ENV{'CARAVEL'}=$ENV{'PWD'}."/$CARAVEL"; # =$(pwd)
  $ENV{'CARAVEL_ROOT'}=$ENV{'PWD'}."/$CARAVEL/caravel";
  $ENV{'PDK_ROOT'}=$ENV{'PDK_ROOT'} || ($ENV{'PWD'}."/$CARAVEL/dependencies/pdks"); # =$(readlink -f $(pwd)/../pdk )
  #$ENV{'PDK'}="gf180mcuD";
  $ENV{'MCW_ROOT'}=$ENV{'PWD'}."/$CARAVEL/mgmt_core_wrapper";
  #$ENV{'PATH'}.=#export PATH=$PATH:$(readlink -f $(pwd)../openlane_summary/ )
  print "Writing Environment file for easy debugging, just \"source env.sh\" when you need it:\n";
  open OUT,">$CARAVEL/env.sh";
  foreach(qw(STDCELLLIB OPENLANE_ROOT CARAVEL CARAVEL_ROOT PDK_ROOT PDK MCW_ROOT))
  {
    print OUT "export $_=\"".$ENV{$_}."\"\n";
  }
  close OUT;

  
  my $pdk=$ENV{'PDK'};
  my $foundry=($pdk=~m/^sky/i)?"SkyWater":($pdk=~m/^gf/i)?"GlobalFoundries":($pdk=~m/^ls/i)?"LibreSilicon":($pdk=~m/^tsmc/i)?"TSMC":"Unknown foundry";
  open OUT,">$CARAVEL/info.yaml";
  print OUT <<EOF
---
project:
  description: "At Libresilicon we have been working for several years on making chipdesign and production available to a wider public. One big step is now to automatically generate standard cell libraries just from the DRC rules and a given or even generated netlist."
  foundry: "$foundry"
  git_url: "https://github.com/thesourcerer8/$CARAVEL.git"
  organization: "Libresilicon Association"
  organization_url: "http://libresilicon.com"
  owner: "Philipp Guehring"
  process: "$pdk"
  project_name: "$CARAVEL"
  project_id: "00000150"
  tags:
    - "Open MPW"
    - "Test Wafer"
    - "Libresilicon"
    - "Librecell"
    - "StdCellLib"
    - "$pdk"
  category: "Test Wafer"
  top_level_netlist: "caravel/verilog/gl/caravel.v"
  user_level_netlist: "verilog/gl/user_project_wrapper.v"
  version: "1.00"
  cover_image: "docs/source/_static/user_proj_example.gds.png"
EOF
;
  close OUT;


  open OUT,">$CARAVEL/README.md";
  print OUT <<EOF
# Caravel User Project for testing automatically generated Standard Cells

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0) [![UPRJ_CI](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/user_project_ci.yml) [![Caravel Build](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml/badge.svg)](https://github.com/efabless/caravel_project_example/actions/workflows/caravel_build.yml)

This is a Multi-Project-Wafer submission for the $pdk process node which is automatically generated by the LibreSilicon StdCellLib Toolchain at https://github.com/thesourcerer8/StdCellLib .
It contains the following cells:

EOF
;
  print OUT join("\n",map { "* ".$_ } keys %{$assigned{$CARAVEL}});
  close OUT;

  mkdir "$CARAVEL/dependencies",0777;
  chdir "$CARAVEL";
  system_v "perl ../../Tools/caravel/iogenerator.pl >verilog/rtl/user_defines.v";


  chdir "cells/lef";
  step("fixup_lef $CARAVEL");
  system "perl ../../../../Tools/caravel/fixup_lef.pl ../../../../Tech/libresilicon.tech";
  chdir "../../../";
  chdir "$CARAVEL/cells/mag";
  step("fixup_mag $CARAVEL");
  system "perl ../../../../Tools/caravel/fixup_mag.pl ../../../../Tech/libresilicon.tech" if($magictech eq "sky130A");
  chdir "../../../";
  chdir "$CARAVEL/cells/sp";
  step("fixup_sp $CARAVEL");
  system "perl ../../../../Tools/caravel/fixup_sp.pl ../../../../Tech/libresilicon.tech";
  chdir "../../../";
  chdir "$CARAVEL/cells/gds";
  step("fixup_gds $CARAVEL");
  #system "python3 ../../../../Tools/caravel/scale10.py";
  chdir "../../../";


  chdir "$CARAVEL/cells/lib";
  step("libertymerge");
  system_v "libertymerge -b ../../../libresilicon.libtemplate -o libresilicon.lib -u *.lib";
  step("removenl");
  system "perl ../../../../Tools/caravel/removenl.pl >new.lib";
  rename "libresilicon.lib","libresilicon.lib.orig";
  rename "new.lib","libresilicon.lib";
  chdir "../../../";

  step("config");
  chdir $CARAVEL;

  system_v "perl ../../Tools/caravel/configgen.pl >openlane/user_proj_example/config.json";


open OUT,">openlane/user_proj_example/config.tcl";
print OUT <<EOF
# SPDX-FileCopyrightText: 2023 Libresilicon Autogenerated
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0

set ::env(PDK) "$pdk"
set ::env(STD_CELL_LIBRARY) "$celllibrary"

set ::env(DESIGN_NAME) user_proj_example

set ::env(EXTRA_LEFS) "\$::env(DESIGN_DIR)/../../cells/lef/*.lef"

set ::env(VERILOG_FILES) "\$::env(CARAVEL_ROOT)/verilog/rtl/defines.v \$::env(DESIGN_DIR)/../../verilog/rtl/user_proj_example.v"

set ::env(DESIGN_IS_CORE) 0

set ::env(CLOCK_PORT) "wb_clk_i"
set ::env(CLOCK_NET) "counter.clk"
set ::env(CLOCK_PERIOD) "24.0"

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 700 700"

set ::env(FP_PIN_ORDER_CFG) \$::env(DESIGN_DIR)/pin_order.cfg

set ::env(PL_BASIC_PLACEMENT) 0
set ::env(PL_TARGET_DENSITY) 0.45

set ::env(FP_CORE_UTIL) 40

set ::env(SYNTH_MAX_FANOUT) 4

# Maximum layer used for routing is metal 4.
# This is because this macro will be inserted in a top level (user_project_wrapper) 
# where the PDN is planned on metal 5. So, to avoid having shorts between routes
# in this macro and the top level metal 5 stripes, we have to restrict routes to metal4.  
# 
set ::env(RT_MAX_LAYER) {Metal4}

# You can draw more power domains if you need to 
set ::env(VDD_NETS) [list {vdd}]
set ::env(GND_NETS) [list {vss}]

set ::env(DIODE_INSERTION_STRATEGY) 4 
# If you're going to use multiple power domains, then disable cvc run.
set ::env(RUN_CVC) 1
EOF
  ;
  close OUT;
  rename "openlane/user_proj_example/config.tcl","openlane/user_proj_example/config.tcl.old";

  if(open(OUT,">>openlane/user_proj_example/pin_order.cfg"))
  {
    foreach(16..37)	   
    {
      print OUT "io_in\\[$_\\]\n";
      print OUT "io_out\\[$_\\]\n";
      print OUT "io_oeb\\[$_\\]\n";
    }
    close OUT;
  }



  step("generator");
  chdir $CARAVEL;
  system "perl ../../Tools/caravel/generator.pl >verilog/rtl/user_proj_example.v";
  step("cells");
  system "perl ../../Tools/caravel/cells.pl >verilog/rtl/user_proj_cells.v";
  step("placement");
  system "perl ../../Tools/caravel/placement.pl >openlane/user_proj_example/macro_placement.cfg";

  step("verification");
  mkdir "verilog/dv/stdcells",0755;
  mkdir "verilog/dv/cocotb",0755;
  system "cp ../../Tools/caravel/stdcells_tb.v verilog/dv/stdcells/";
  system "cp verilog/dv/io_ports/Makefile verilog/dv/stdcells/" if(-f "verilog/dv/io_ports/Makefile");
  chdir "cells/cell";
  system_v "perl ../../../../Tools/perl/testgen.pl >../../verilog/dv/stdcells/stdcells.c";
  chdir "../../";
  
  step("make setup");
  system_v "make setup";
  step("make user_proj_example");
  system_v "make user_proj_example && make user_project_wrapper";
  if($doverification)
  {
    system_v "make simenv";
    system_v "make verify-stdcells-rtl";
  }
  system_v "make dist";

  if(0)
  {
  system_v "git add cells env.sh verilog/rtl/user_proj_cells.v verilog/rtl/user_proj_example.v openlane/user_proj_example/* info.yaml verilog/dv/stdcells";
  system_v "git commit -m \"Automatically generated files\"";
  system_v "git add -u .";
  system_v "git add gds/*";
  system_v "git commit -m \"Openlane generated files\"";
  system_v "git remote remove origin";
  system_v "git remote add origin git\@github.com:$githubuser/$CARAVEL.git";
  system_v "echo git push origin HEAD:main -f";
  }
  else
  {
  #system_v "git clone ssh://git\@repositories.efabless.com/$efablessuser/$CARAVEL.git";
  system_v "git remote rename origin upstream";
  system_v "git remote add origin ssh://git\@repositories.efabless.com/$efablessuser/$CARAVEL.git";
  #system_v "cd gf180_stdcelllib_1";
  #system_v "git checkout -b main";
  system_v "touch README.rst";
  system_v "git add README.rst";
  system_v "git commit -m \"Add README file\"";
  system_v "echo git push -u origin main";

  }
  chdir "..";
}

print "Selecting first group:\n";
nextgroup($group);
# Too complex cells:AAOAOI33111.cell AAOOAAOI2224.cell AOAAOI2124.cell OAAAOI2132.cell OAAOAOI21311.cell OAAOI224.cell OAOOAAOI21132.cell AAAAOI3322.cell AAAOAI3221.cell AAAOAOI33311.cell AAAOI222.cell
my @cells=qw(NAND2.cell AAAOI333.cell AAOI22.cell AOAI221.cell AOI21.cell ASYNC1.cell ASYNC2.cell ASYNC3.cell INV.cell MARTIN1989.cell MUX2.cell MUX3.cell MUX4.cell MUX8.cell NAND3.cell NAND4.cell NOR2.cell NOR3.cell NOR4.cell OAI41.cell OOOOAI3332.cell OR4.cell sutherland1989.cell vanberkel1991.cell );
#push @cells,<*.cell>;
my %seen=();

print "Adding all the cells onboard the Caravels:\n";
foreach my $cell (@cells)
{
  next if(defined($seen{$cell}));
  $seen{$cell}=1;
  my $thisios=0;
  my $cn=$cell; $cn=~s/\.cell$//;
  next if(-f "cn.dontuse");
  if(! -s "$cn.truthtable.v")
  {
    print "The cell $cell has an empty and unusable truthtable.\n";
    next;
  }
  if(-f "outputlib/$cn.gds")
  {
    open IN,"<$cell";
    while(<IN>)
    {
      if(m/^\.(inputs|outputs) (.*)$/)
      {
	@ins=split(" ",$2);
	$thisios+=@ins;
      }
    }
    close IN;
    $totalios+=$thisios;
    if(($usedios+$thisios)>$maxios)
    {
      $usedios=0;
      $group++;
      print "NEXT GROUP\n";
      my $res=nextgroup($group);
      last unless($res);
    }
    $usedios+=$thisios;
    $totalios+=$thisios;
    print "$group $cn $thisios\n";
    addcell($group,$cn); 
  }

}
print "Now shipping all the Caravels\n";
endgroup($_) foreach(@repos);
print "All Caravels are done.\n";
