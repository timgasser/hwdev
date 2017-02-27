#!/usr/bin/perl -w

# Turn on some strict checking just in case 
use strict;
use warnings;
use File::Path;



# This utility reads in the hex output from objcopy, and outputs a ROM 
# TODO:
#
#
# 

# This is the example from the XST guide
# //
# // ROMs Using Block RAM Resources.
# // Verilog code for a ROM with registered output (template 1)
# //
# module v_rams_21a (clk, en, addr, data);
#     input      clk;
#     input      en;
#     input      [5:0] addr;
#     output reg [19:0] data;
#     always @(posedge clk) begin
#         if (en)
#             case(addr)
#                 6’b000000: data <= 20’h0200A;   6’b100000: data <= 20’h02222;
#                 6’b000001: data <= 20’h00300;   6’b100001: data <= 20’h04001;
#                 6’b000010: data <= 20’h08101;   6’b100010: data <= 20’h00342;
#                 6’b000011: data <= 20’h04000;   6’b100011: data <= 20’h0232B;
#                 6’b000100: data <= 20’h08601;   6’b100100: data <= 20’h00900;
#                 6’b000101: data <= 20’h0233A;   6’b100101: data <= 20’h00302;
#                 6’b000110: data <= 20’h00300;   6’b100110: data <= 20’h00102;
#                 6’b000111: data <= 20’h08602;   6’b100111: data <= 20’h04002;
#                 6’b001000: data <= 20’h02310;   6’b101000: data <= 20’h00900;
#                 6’b001001: data <= 20’h0203B;   6’b101001: data <= 20’h08201;
#                 6’b001010: data <= 20’h08300;   6’b101010: data <= 20’h02023;
#                 6’b001011: data <= 20’h04002;   6’b101011: data <= 20’h00303;
#                 6’b001100: data <= 20’h08201;   6’b101100: data <= 20’h02433;
#                 6’b001101: data <= 20’h00500;   6’b101101: data <= 20’h00301;
#                 6’b001110: data <= 20’h04001;   6’b101110: data <= 20’h04004;
#                 6’b001111: data <= 20’h02500;   6’b101111: data <= 20’h00301;
#                 6’b010000: data <= 20’h00340;   6’b110000: data <= 20’h00102;
#                 6’b010001: data <= 20’h00241;   6’b110001: data <= 20’h02137;
#                 6’b010010: data <= 20’h04002;   6’b110010: data <= 20’h02036;
#                 6’b010011: data <= 20’h08300;   6’b110011: data <= 20’h00301;
#                 6’b010100: data <= 20’h08201;   6’b110100: data <= 20’h00102;
#                 6’b010101: data <= 20’h00500;   6’b110101: data <= 20’h02237;
#                 6’b010110: data <= 20’h08101;   6’b110110: data <= 20’h04004;
#                 6’b010111: data <= 20’h00602;   6’b110111: data <= 20’h00304;
#                 6’b011000: data <= 20’h04003;   6’b111000: data <= 20’h04040;
#                 6’b011001: data <= 20’h0241E;   6’b111001: data <= 20’h02500;
#                 6’b011010: data <= 20’h00301;   6’b111010: data <= 20’h02500;
#                 6’b011011: data <= 20’h00102;   6’b111011: data <= 20’h02500;
#                 6’b011100: data <= 20’h02122;   6’b111100: data <= 20’h0030D;
#                 6’b011101: data <= 20’h02021;   6’b111101: data <= 20’h02341;
#                 6’b011110: data <= 20’h00301;   6’b111110: data <= 20’h08201;
#                 6’b011111: data <= 20’h00102;   6’b111111: data <= 20’h0400D;
#             endcase
#     end
# endmodule
# 


my $Header = "                    
// ROMs Using Block RAM Resources
// Verilog code for a ROM with registered output (template 1)
//
// This file is auto-generated ! Please do not edit!
// 
// The bootrom is up to 32kByte big, but will only contain valid data from code.hex
// It can use anything up to 16 BRAMs and there are only 48 in the FPGA (!).
// The max is therefore 8192 x 32 bit words. 
// So you need a 13 bit address, although some of these bits may be optimised away
// depending on how many values there are in the case statement below.

module INST_ROM (clk, en, addr, data);
    input      clk;
    input      en;
    input      [12:0] addr;
    output reg [31:0] data;
    always @(posedge clk) begin
        if (en)
            case(addr)
";

my $Footer = "
            endcase
    end
endmodule
";




# Reads through a netlist, finding modules and extracting them into separate verilog files
# to enable a diff of netlists between projects

# The name of the netlist file (todo ! put this in a command line argument)
my $InFile;
my $OutFile;


# Put some variables here to list the modules
my $TheLine;
my $LineCount = 0;

my $ByteLoop;
my $WordLoop;
my $NumWords;
my $NumBytes;

my $CurrentWord;
my $CurrentByte;

my @LineList; # List of bytes in the line
my @ByteList; # List of bytes (little endian)
my @WordList; # List of words (built from ByteList)

my $AddrLoop;

my $InModule;
my $CurrentModule;

my $Instruction;

$InModule = 0;

my $LineAddr;

# First of all check for the arguments
if ($#ARGV < 1)
{
#  print "\n";
  print "1 or less arguments specified.\n";
  print "Usage is hex2imem.pl <hexfile name> <verilog rom name>\n";
  print "\n";
  exit;
}
elsif ($#ARGV == 1) # 2 arguments
{
  $InFile  = $ARGV[0];
  $OutFile = $ARGV[1];

  # Open the file, check if it doesn't exist
  open(INFILE, $InFile) or die "The file $InFile couldn't be found";
  open(OUTFILE, " > $OutFile") or die "Problem opening $OutFile for output";
}

print("Converting $InFile to $OutFile  ...\n");

while (<INFILE>)
{

  # Read the line in, take line ending off
  $TheLine = $_;
  chomp($TheLine);
  $LineCount++;
  
  print("INFO: Procesing line $LineCount\n");

# Discard any lines with a /* comment */  in them
  if ($TheLine =~ m/http:\/\/srecord.sourceforge.net/)
  {
      print("Discarding Line $LineCount = $TheLine\n");
      next;
  }
# Otherwise split the line into bytes.
  else
  {
      @LineList = split(/ /, $TheLine); 
  }

  # Remove the first element of the array (contains @ Address)
  shift (@LineList);

  push (@ByteList, @LineList);

#  print("INFO: NumWords = $NumWords\n");
#  print("INFO: ByteList = ");
 

#  print("INFO: WordList = ");
#  print join(',', @WordList), "\n";
#  print("\n");

}
  
close(INFILE);


foreach (@ByteList) { print $_; }
print("\n");

$NumBytes = @ByteList;
$NumWords = $NumBytes / 4;
print("Found $NumBytes bytes ($NumWords words) in $InFile -> $OutFile\n");



# Put each of the bytes in little endian order into the Wordlist list
# unshift adds items to the left side of a list
for ($WordLoop = 0 ; $WordLoop < $NumWords ; $WordLoop++)
{
    unshift(@WordList, $ByteList[($WordLoop * 4) + 3]);
    unshift(@WordList, $ByteList[($WordLoop * 4) + 2]);
    unshift(@WordList, $ByteList[($WordLoop * 4) + 1]);
    unshift(@WordList, $ByteList[($WordLoop * 4) + 0]);
    
}


# WordList now contains a list of byte values in little endian order.
# We want to pop (remove from right-end of list) words out

print(OUTFILE "$Header");

$AddrLoop = 0;

# Only generate a case statement where the data is actually present in the
# code.hex. Otherwise you use massive amounts of BRAM to store empty data!
# This way synthesis can just store the actual data and return a 0 for empty areas

while ($#WordList > 0)
{
  printf(OUTFILE "                  13\'d%04d: data <= 32'h", $AddrLoop);

  $CurrentByte = pop(@WordList);
  print(OUTFILE "$CurrentByte");
  $CurrentByte = pop(@WordList);
  print(OUTFILE "$CurrentByte");
  $CurrentByte = pop(@WordList);
  print(OUTFILE "$CurrentByte");
  $CurrentByte = pop(@WordList);
  print(OUTFILE "$CurrentByte");

  $AddrLoop++;
  print(OUTFILE ";\n");
}

print(OUTFILE "                  default : data <= 32'h00000000;\n");


print(OUTFILE "$Footer");


# Close the files after using them
close(OUTFILE);
