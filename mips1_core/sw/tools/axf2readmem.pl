#!/usr/bin/perl -w

# TODO list: Print out debuggin info on what section is being converted
#            Check the instruction addresses to make sure it increments by 4 with no gaps (remember in hex !)



# Turn on some strict checking just in case 
use strict;
use warnings;
use File::Path;

# Reads through a netlist, finding modules and extracting them into separate verilog files
# to enable a diff of netlists between projects

# The name of the netlist file (todo ! put this in a command line argument)
my $InFile;
my $OutFile;


# Put some variables here to list the modules
my $TheLine;
my $LineCount;
my @WordList;

my $InModule;
my $CurrentModule;

my $Instruction;

$InModule = 0;

# First of all check for the arguments
if ($#ARGV == -1)
{
#  print "\n";
  print "No arguments specified.\n";
  print "Usage is axf2readmem.pl <axf name>\n";
  print "\n";
  exit;
}
elsif ($#ARGV == 0) # 1 argument
{
  $InFile = $ARGV[$#ARGV];

  # Open the file, check if it doesn't exist
  open(INFILE, $InFile) or die "The file $InFile couldn't be found";
  open(OUTFILE, "> code.txt") or die "Problem opening code.txt for output";

}

print("Converting AXF to readmemh format ...\n");

while (<INFILE>)
{

  # Read the line in, take line ending off
  $TheLine = $_;
  chomp($TheLine);
  $LineCount++;

  
  # If the line has 'format' in it, print debugging info of type
  if ($TheLine =~ m/format/)
  {
    @WordList = split(/ /, $TheLine);
    print("Converting file of format $WordList[$#WordList]\n");
  }

  if ($TheLine =~ m/:	/)
  {
    @WordList = split(/:	/, $TheLine);
    
    if ($WordList[0] ne 'test.axf')
    {
      $Instruction = substr($WordList[1], 0, 8);
      print("DEBUG: Address $WordList[0]  - Instruction $Instruction\n");
      print(OUTFILE "$Instruction\n");
    }
  }
}


# Close the files after using them
close(OUTFILE);
close(INFILE);
