 #!/usr/bin/perl -w

# Turn on some strict checking just in case 
use strict;
use warnings;
use File::Path;


# This file reads in the .par file intended for dejagnu and checks to see if the registers match

# The name of the netlist file (todo ! put this in a command line argument)
my $InFile;
my $OutFile;


# Put some variables here to list the modules
my $TheLine;
my $LineCount = 0;

my $ByteLoop;
my $NumWords;
my $NumBytes;

my $CurrentReg;
my $CurrentRegVal;

my @ByteList; # List of bytes (little endian)
my @WordList; # List of words (built from ByteList)
my $WordLoop; # Loop variable
my $ArraySize;

my @ParRegNames;
my @ParRegValues;

my @RegValues;

my $AddrLoop;

my $InModule;
my $CurrentModule;

my $Instruction;

my $RegLoop;

my $NumRegsToCheck;

my $PassCount = 0;
my $FailCount = 0;

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
  open(PARFILE, $InFile) or die "The file $InFile couldn't be found";
}

print("Comparing expected file $InFile to actual file $OutFile  ...\n");

while (<PARFILE>)
{

  # Read the line in, take line ending off
  $TheLine = $_;
  chomp($TheLine);
  $LineCount++;
  
  print("INFO: Procesing line $LineCount: ");

# Discard any lines with an @ in them
  if (($TheLine =~ m/R/)  || ($TheLine =~ m/r/) && (!($TheLine =~ m/regcheck_set_results/)))
  {
      @WordList =  split(' ', $TheLine); 

      $ArraySize = @WordList;

      for ($WordLoop = 0 ; $WordLoop < $ArraySize ; $WordLoop++)
      {
	  if (($WordList[$WordLoop] =~ m/R/) || ($WordList[$WordLoop] =~ m/r/))
	  {
	      $CurrentReg    = substr($WordList[$WordLoop], 1, 2);
	      $CurrentRegVal = substr($WordList[$WordLoop + 1], 0, 8);

	      print("CurrentReg =  $CurrentReg, ");
	      print("CurrentRegVal =  $CurrentRegVal\n");

	      unshift (@ParRegNames  , $CurrentReg );
	      unshift (@ParRegValues , $CurrentRegVal);
	  }
	  
      }
  }
  else
  {
      print ("\n");
  }

}

#  foreach (@ParRegNames) { print "$_\n" ; }
#  foreach (@ParRegValues) { print "$_\n" ; }
  print("\n");
 
  # Put each of the by
close(PARFILE);

open(REGFILE, "$OutFile") or die "Problem opening $OutFile for output";

print("Reading simulation results .. \n");
$LineCount = 0;

while (<REGFILE>)
{

  # Read the line in, take line ending off
  $TheLine = $_;
  chomp($TheLine);

  # Discard any lines with // in them
  if ($TheLine =~ m/\/\//)
  {
      print ("INFO: Dropping line (found //)\n");
  }
  else
  {
      print ("INFO: Storing Reg $LineCount = $TheLine\n");      
      push (@RegValues  , $TheLine );
      $LineCount++;
  }
}

# foreach (@RegValues) { print "$_\n" ; }

close(REGFILE);

$NumRegsToCheck = @ParRegNames;

print ("INFO: Comparing $NumRegsToCheck registers in test results\n");
for ($RegLoop = 0; $RegLoop < $NumRegsToCheck ; $RegLoop++)
{

    $CurrentReg = $ParRegNames[$RegLoop];
    print("INFO: Comparing Reg $CurrentReg\n");

    if ($ParRegValues[$RegLoop] eq $RegValues[$CurrentReg])
    {
	print("OK: $ParRegValues[$RegLoop] == $RegValues[$ParRegNames[$RegLoop]]\n");
	$PassCount++;
    }
    else
    {
	print("ERROR: $ParRegValues[$RegLoop] != $RegValues[$ParRegNames[$RegLoop]]\n");
	$FailCount++;
    }
}

print("\n");
if (($FailCount == 0) && ($PassCount != 0))
{
    print("TEST SUMMARY: PASS \n");
}
else
{
    print("TEST SUMMARY: FAIL \n");
}

print("Registers matching: ($PassCount \/ $NumRegsToCheck)\n");


print("\n");
