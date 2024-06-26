#!/usr/bin/perl -w

my $STDCELLLIB=$ENV{'STDCELLLIB'} || "/home/philipp/libresilicon/StdCellLib";

print STDERR "Generates Verilog for user_proj_example\n";

print STDERR "Warning: environment variable CARAVEL not defined! Please define it.\n" unless (-d $ENV{'CARAVEL'}."/cells/mag/");


print <<EOF
`default_nettype none
`include "user_proj_cells.v"

/*
 *-------------------------------------------------------------
 *
 * user_proj_ls130tw1  (LibreSilicon Testwafer #1)
 *
 */

module user_proj_example #(
  /*  parameter BITS = 32 */
)(
`ifdef USE_POWER_PINS
EOF
;

if($ENV{'PDK'}=~m/^sky130/i)
{
  print <<EOF
    inout vdda1,        // User area 1 3.3V supply
    inout vdda2,        // User area 2 3.3V supply
    inout vssa1,        // User area 1 analog ground
    inout vssa2,        // User area 2 analog ground
    inout vccd1,        // User area 1 1.8V supply
    inout vccd2,        // User area 2 1.8v supply
    inout vssd1,        // User area 1 digital ground
    inout vssd2,        // User area 2 digital ground
EOF
  ;
}
elsif($ENV{'PDK'}=~m/^gf180/i)
{
  print <<EOF
    inout vdd,
    inout vss,
EOF
  ;
}
else
{
  print STDERR "WARNING: We could not recognize the PDK from the environment variable PDK, we assume the power pins are named vdd/vss.\n";
  print <<EOF
    inout vdd,
    inout vss,
EOF
  ;
}
print <<EOF
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq

);

    wire [`MPRJ_IO_PADS-1:0] io_in_wire;
    assign io_in_wire=io_in;

    wire [127:0] la_data_in_wire;
    assign la_data_in_wire=la_data_in;


    // IRQ
    assign irq = 3'b000;	// Unused

EOF
;


our $nextla=0;
our $nextio=0;
our $conf="";
my $MPRJ_IO_PADS=38;

my %driven=();

foreach my $mag(<cells/mag/*.mag>)
{
  next if((-s $mag)<=50);
  #print `ls -la $mag`;
  my $cell=$mag; $cell=~s/\.mag$/.cell/; $cell=~s/\/mag\//\/cell\//;
  my $lib=$mag; $lib=~s/\.mag$/.lib/; $lib=~s/\/mag\//\/lib\//;

  my $name=""; $name=$1 if($mag=~m/([\w\-\.]+)\.mag$/);
  next unless(-f $cell);
  #next unless(-f $lib);
  #next unless(-f $ENV{'CARAVEL'}."/cells/mag/$name.mag");

  open CELL,"<$cell";
  print "$name $name(\n";
  print " `ifdef USE_POWER_PINS\n";
  print "  \.VPWR(vccd1),\n"; # ??? Should we do 3.3V or 1.8V ?
  print "  \.VGND(vssd1),\n";
  print " `endif\n";

  my $counter=0;
  while(<CELL>)
  {
    if(m/^\.inputs (.*)/)
    {
      foreach my $inp(sort split " ",$1)
      {
        my $io=$nextio++;
	if($io<$MPRJ_IO_PADS)
	{
          print "  ".($counter?', ':'')."\.$inp(io_in_wire[$io])\n";
	  $conf.="assign io_oeb[$io] = 1'b1;\n";
          $inout{"io$io"}="ioin";
	  $counter++;
	}
	else
	{
	  my $la=$io-$MPRJ_IO_PADS;
          print "  ".($counter?', ':'')."\.$inp(la_data_in_wire[$la])\n";
          $inout{"io$io"}="lain";
	  $counter++;
	}
      }
    }
    if(m/^\.outputs (.*)/)
    {
      foreach my $outp(sort split " ",$1)
      {
        my $io=$nextio++;
	if($io<$MPRJ_IO_PADS)
	{
          print "  ".($counter?', ':'')."\.$outp(io_out[$io])\n";
	  $driven{"io_out[$io]"}=1;
	  $conf.="assign io_oeb[$io] = 1'b0;\n";
          $inout{"io$io"}="ioout";
	  $counter++;
	}
	else
	{
	  my $la=$io-$MPRJ_IO_PADS;
          print "  ".($counter?', ':'')."\.$outp(la_data_out[$la])\n";
	  $driven{"la_data_out[$la]"}=1;
          $inout{"io$io"}="laout";
	  $counter++;
	}
      }
    }

  }
  close CELL;

  print ");\n";
}

  foreach(0 .. 127)
  {
    print "assign la_data_out[$_] = 1'b0;\n" if(!defined($driven{"la_data_out[$_]"}));
  }
  foreach(0 .. $MPRJ_IO_PADS-1)
  {
    print "assign io_out[$_] = 1'b0;\nassign io_oeb[$_] =1'b0;\n" if(!defined($driven{"io_out[$_]"}));
  }

  print "assign wbs_ack_o = 1'b1;\n";
  print "assign wbs_dat_o = 32'b0;\n";

print $conf;
print "endmodule\n";
print "`default_nettype wire\n";
