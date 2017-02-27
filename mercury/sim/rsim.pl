#!/usr/bin/perl

# Turn on some strict checking just in case 
use strict;
use warnings;
use File::Path;
use File::Copy;
use File::Compare;
use Cwd;

my $swDir = "../../sw";

my $asmSrc;
my $simDir;
my $currDir;

#  Build up GNU tools strings
my $gnuDir    = "/home/tim/bin/x-tools/mipsel-unknown-linux-gnu/bin";
my $gnuPrefix = "mipsel-unknown-linux-gnu-";

my $gnuAs    = "$gnuDir/$gnuPrefix" . 'as';
my $gnuGcc   = "$gnuDir/$gnuPrefix" . 'gcc';
my $gnuLd    = "$gnuDir/$gnuPrefix" . 'ld';
my $gnuDump  = "$gnuDir/$gnuPrefix" . 'objdump';
my $gnuCopy  = "$gnuDir/$gnuPrefix" . 'objcopy';

# Flags to use with GNU tools
my $asFlags = '-EL -mips1';
my $cFlags  = '-EL -c -O0 -mno-float -mips1 ';
my $ldFlags = '-EL  --script ld.script -eentry -s -N -Map test.map'; 

my $dumpFlags = '-D -EL -w -z --disassembler-options=no-aliases,reg-names=numeric';
my $copyFlags = '--only-section .text -O ihex -S';

my $vlogFlags = '-sv -hazards -timescale "1 ns / 1 ps" -incr -novopt';
my $vsimFlags = '-novopt -c -debugDB=vsim.dbg -wlf vsim.wlf -do "add log -r /* ; run -all" ';

my $vlogRtlDir       = '/home/tim/projects/hwdev/mips1_core/rtl';
my $vlogTbDir        = '/home/tim/projects/hwdev/mips1_core/tb';
my $vlogTbCommonDir  = '/home/tim/projects/hwdev/common/tb';

my $vlogSrc          = "$vlogTbDir/tb_cpu_core_bfm.v  $vlogTbDir/cpu_core_monitor.v  $vlogTbCommonDir/wb_slave_bfm.v   $vlogRtlDir/cpu_core.v";
my $vlogIncdir       = '/home/tim/projects/hwdev/mips1_core/rtl/inc';

my $charLoop;

my $asmDir;
my $asmStem;
my $asmExt;

my @dotList;
my @slashList;

my $dotPosn;
my $slashPosn;

my $runRegr = 0;
my @regrList;
my @passList;
my $numTests;

my $currTest;
my $testLoop;

my $returnCode;

my $summaryFile = "test_summary.txt";

my $startTime;
my $endTime;
my $scriptTime;

$startTime = time;

# First of all check for the arguments
if ($#ARGV == 0)
{
#  print "\n";
  print "[INFO ] Running test $ARGV[0]\n";
}
else
{
    print "[ERROR] Need to specify test name\n";
    exit;
}


if (-f "$swDir/$ARGV[0]") 
{
    print("[INFO ] Found single test file $swDir/$ARGV[0]\n");
    $runRegr = 0;
    unshift(@regrList, "$swDir/$ARGV[0]");
    $numTests = 1;
}
elsif (-d "$swDir/$ARGV[0]") 
{
    print("[INFO ] Found regression directory $swDir/$ARGV[0]\n");
    $runRegr = 1;

    opendir(DIR, "$swDir/$ARGV[0]") or die $!;


    @regrList = grep(/\.s$/,readdir(DIR));
    closedir(DIR);

    $numTests = @regrList;
    print("[INFO ] Found $numTests tests\n");

     foreach (@regrList) 
     {
	 $_ = "$swDir/$ARGV[0]/" . $_ ;
     }

    @regrList = sort(@regrList);

    print join("\n", @regrList);
    print("\n");

}
else
{
    die("[ERROR] Test $swDir/$ARGV[0] not found\n");
}

for ($testLoop = 0 ; $testLoop < $numTests ; $testLoop++)
{
   
    $currTest = $regrList[$testLoop];  

    $dotPosn = length($currTest) - 1;    
    while (substr ($currTest, $dotPosn, 1) ne ".")
    {
	$dotPosn--;
    }

    $asmExt = substr($currTest, $dotPosn, length($currTest) - $dotPosn);

    $slashPosn = $dotPosn;
    while (substr ($currTest, $slashPosn, 1) ne "/")
    {
	$slashPosn--;
    }
    
    $asmStem = substr($currTest, $slashPosn + 1, $dotPosn - $slashPosn - 1);
    $asmDir  = substr($currTest, 0, $slashPosn);
    $asmSrc = "$asmDir/$asmStem$asmExt";
   
    print ("[DEBUG] dotPosn is '$dotPosn'\n");
    print ("[DEBUG] slashPosn is '$slashPosn'\n");

    print ("[DEBUG] asmDir is '$asmDir'\n");
    print ("[DEBUG] asmStem is '$asmStem'\n");
    print ("[DEBUG] asmExt is '$asmExt'\n");

    print ("[DEBUG] asmSrc is '$asmSrc'\n");

# Check the SW file exists or quit out

    if (-e $asmSrc)
    {
	print "[INFO ] Found file $asmSrc\n" ;
    }
    else
    {
	print "[ERROR] Couldn't find file $asmSrc\n";
	die;
    }

    # Replace the sw in asmDir with sim for simulation directory
    $simDir = $asmDir;
    $simDir =~ s/sw/sim/g;
    $simDir = $simDir . '/' . $asmStem; 
    print "[INFO ] Creating simulation directory $simDir\n";

    mkpath("$simDir"); 

    print "[INFO ] Linking source files to directory\n";
    copy("$asmSrc",  "$simDir");
    copy("$asmDir/$asmStem.par", "$simDir");

    print "[INFO ] Changing directory to $simDir\n";
    $currDir = Cwd::abs_path;
    chdir($simDir);

    $returnCode = 0;

    print "[INFO ] Assembling test .. ";
    if (system("$gnuAs $asFlags $asmStem$asmExt -o $asmStem.o") != 0)
    {
	print("ERROR\n");
	push(@passList, "[ERROR] $asmStem$asmExt - Assembler error");
	print "[INFO ] Returning to simulation directory $currDir\n";
	chdir($currDir);
	print(`pwd`);
	next;	
    }
   else
   {
	print("\n");
   }

    print "[INFO ] Generating disassembly\n";
    $returnCode |= system("$gnuDump $dumpFlags $asmStem.o > $asmStem.lst"); #  == 0 or next; # die("[ERROR] Disassembler failed");

    print "[INFO ] Generating ihex format file dump\n";
    $returnCode |= system("$gnuCopy $copyFlags $asmStem.o $asmStem.ihex"); #  == 0 or next; # die("[ERROR] Objcopy failed");

    print "[INFO ] Converting ihex to verilog readmemh format\n";
    $returnCode |= system("srec_cat $asmStem.ihex -Intel -Output $asmStem.hex -VMem 8"); # == 0 or next; # die("[ERROR] Conversion failed");
    $returnCode |= system("ln -s $asmStem.hex test.hex"); # == 0 or die("[ERROR] Error creating symbolic link");

    print "[INFO ] Creating library and compiling verilog files\n";
    $returnCode |= system("vlib work"); #  == 0 or die("[ERROR] Modelsim error creating work library");
    $returnCode |= system("vlog $vlogFlags +incdir+$vlogIncdir $vlogSrc"); #  == 0 or next; # die("[ERROR] Compiling verilog source files");
    $returnCode |= system("vsim $vsimFlags TB_CPU_CORE_BFM");

    print "[INFO ] Comparing registers .. \n";


    if (compare("regfile_dump.hex", "$asmStem.par") == 0)
    {
	print("[PASS ] Test Passed ! :-) \n");
	push(@passList, "[PASS ] $asmStem$asmExt");
    }
    else
    {
	print("[FAIL ] Test Failed ! :-( \n");
	push(@passList, "[FAIL ] $asmStem$asmExt");
    }


    print "[INFO ] Returning to simulation directory $currDir\n";
    chdir($currDir);
    print(`pwd`);


}

print("\n");
print("***** TEST SUMMARY *****\n");
print join("\n", @passList), "\n";

open(SUMMARYFILE, " > $summaryFile") or die "Problem opening $summaryFile for output";
print(SUMMARYFILE "***** TEST SUMMARY *****\n");
print SUMMARYFILE join( "\n", @passList), "\n";

$endTime = time;
$scriptTime = $endTime - $startTime;

printf("\n\nTotal running time: %02d:%02d:%02d\n\n", int($scriptTime / 3600), int(($scriptTime % 3600) / 60), int($scriptTime % 60));
