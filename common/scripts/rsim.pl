#!/usr/bin/perl

# Turn on some strict checking just in case 
use strict;
use warnings;
use File::Path;
use File::Copy;
use File::Compare;
use File::Find;
use Cwd;  
use Getopt::Long;
use File::Basename;



# my $swDir = "../../sw";

my $asmSrc;
# my $simDir;
my $currDir;

################################################################################
# Testcase Assembler configuration

#  GNU tools directories
my $gnuDir    = "/home/tim/bin/x-tools/mipsel-unknown-elf/bin";
my $gnuPrefix = "mipsel-unknown-elf-";

# GNU tool names
my $gnuAs    = "$gnuDir/$gnuPrefix" . 'as';
my $gnuGcc   = "$gnuDir/$gnuPrefix" . 'gcc';
my $gnuLd    = "$gnuDir/$gnuPrefix" . 'ld';
my $gnuDump  = "$gnuDir/$gnuPrefix" . 'objdump';
my $gnuCopy  = "$gnuDir/$gnuPrefix" . 'objcopy';

# GNU tool flags
my $gnuAsFlags    = ' -EL -mips1 -I ..';
my $gnuCFlags     = ' -nostdlib -EL -c -O0 -mips1  -mno-abicalls -fno-pic';
my $gnuLdFlags    = ' -EL  --script ../ld.script -s -N -Map test.map';
my $gnuDumpFlags  = ' -D -EL -w -z --disassembler-options=no-aliases,reg-names=numeric --source';
my $gnuCopyFlags  = ' --only-section .text -O srec -S';

# combined command and flags
my $cmdAs    = $gnuAs   . $gnuAsFlags   ;
my $cmdGcc   = $gnuGcc  . $gnuCFlags    ;
my $cmdLd    = $gnuLd   . $gnuLdFlags   ;
my $cmdDump  = $gnuDump . $gnuDumpFlags ;
my $cmdCopy  = $gnuCopy . $gnuCopyFlags ;
my $cmdHexToRom = $ENV{'HWROOT'} . "/common/scripts/hex2imem.pl";




################################################################################
# Testbench C model configuration

# DPI C compiler settings
my $dpiDir= $ENV{'HWROOT'} . "/mips1_core/tb";
my $dpiTb="${dpiDir}/tb_cpu_core_bfm";
my $dpiCSrc=""; # "mlite_dpi" <- fill this with all the DPI C files
my $dpiCC="gcc -g -c -m32 -fPIC -Wall -ansi -pedantic -I. -I" . $ENV{MTI_HOME} . "/include";
my $dpiLD="gcc -shared -lm -m32 -Wl,-Bsymbolic -Wl,-export-dynamic -o ";
my $dpiSo='testcase';
################################################################################
# Modelsim configuration

# Base flags for the vlog and vsim stages
my $baseVlogFlags = '-sv -hazards -incr -vopt -timescale "1 ns / 1 ps" -mfcu';
my $baseVsimFlags = '';
# Dynamic flags (built per test depending on DPI)
my $vlogFlags;
my $vsimFlags;



my $vlogRtlDir       = '/home/tim/projects/hwdev/mips1_core/rtl';
my $vlogTbDir        = '/home/tim/projects/hwdev/mips1_core/tb';
my $vlogTbCommonDir  = '/home/tim/projects/hwdev/common/tb';
my $coregenDir       = '/home/tim/projects/hwdev/coregen';
my $xilinxDir        = '/home/tim/bin/xilinx/ISE_DS/ISE/verilog/src/unisims';


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
# my $numTests;

# my $currTest;
# my $testLoop;

my $returnCode;

my $summaryFile = "test_summary.txt";

my $startTime;
my $endTime;
my $scriptTime;

$startTime = time;

# Set up command options and default value
my $argNoClean  = 0          ; # Boolean : Clean up all non-Perforce files in sim dir
my $argDef      = ""         ; # String  : List of defines to use in compilation
my $argDump     = 0          ; # Boolean : Whether to dump simulation results or not
my $argDo       = ""         ; # String  : .do file to pass to run stage
my $argCover    = 0          ; # Boolean : Whether to record coverage information
my $argGui      = 0          ; # Boolean : Whether to run an interactive GUI session
my $argSeed     = "random"   ; # String  : SV seed to use in the vsim run stage

# Help parameters, print help if set.
my $argH      = 0;
my $argHelp   = 0;

# Debugging option to check script operation
my $rsimDebug = 0;

# Amount of arguments
my $argRetVal;

# Regression mode arguments
my $argRegressFile = "";
my $numRegDirs = 0;
my @regressDirs;
my $currRegressDir;

# Array of tests and directories
my @testArray;
my @testResultArray;
my $callDir;  # Where the rsim.pl was run
my $simDir;   # the location of 'sim' in the corresponding /sim/xyz/test2
my $tbDir;    # Testbench directory for current test
my $testDir;
my $numTests;
my $currTest;
my $testLoop;

my %testAssocArray;

# Info to print if help is requested
my $helpInfo = " 
///////////////////////////////////////////////////////////////////////////////////
// rsim.pl : Runs all tests under the current directory   
///////////////////////////////////////////////////////////////////////////////////

Valid options are:

--noclean         : Do not remove temporary simulation files before compile and 
                    simulate. May speed up overall compile.
                    Default is False.

--def MACRO[=VAL] : Defines the Macro, and optionally sets it to the VAL value.

--dump            : Creates a waveform dump of the simulation for post-processing.
                    Default is False.

--do DOFILE.do    : Adds the specified DOFILE.do to the vsim invocation.

--cover           : Generates coverage database for post-processing.
                    Default is False.

--gui             : Runs an interactive GUI simulation.
                    Default is False.

--seed SEED_VAL   : Runs the simulation with the specified SEED_VAL. 
                    Default is random.

--regress[=VAL]   : Runs a regression, with test list spacified in VAL

-h, --help        : Prints this message

--debug           : Prints debugging information from the script

///////////////////////////////////////////////////////////////////////////////////

";



################################################################################
# Printing options.
#
sub debugPrint
{
    if ($rsimDebug)
    {
        print("[DEBUG] $_[0]");
    }
}

sub infoPrint
{
    print("[INFO ] $_[0]");
}

sub errorPrint
{
    print("[ERROR] $_[0]");
    exit;
}

################################################################################
# system wrapper with a check for the debug option. If so, the command and return
# value are printed out..
sub systemWrap
{
    my $returnVal;
    my $systemCmd;

    $systemCmd = $_[0];

    if ($rsimDebug)
    {
        $returnVal = system("$systemCmd");
        die "\n[ERROR] SYSTEM Error executing $systemCmd " unless (!$returnVal);
        debugPrint("SYSTEM  : Command      = $systemCmd\n");
        debugPrint("SYSTEM  : Return value = $returnVal\n");
        debugPrint("\n");
    }
    else
    {
        $returnVal = system("$systemCmd");
        die "\n[ERROR] SYSTEM Error executing $systemCmd " unless (!$returnVal);
    }
}

################################################################################
# Sub to use with File::Find to store testcase.v's in the testArray
#
sub addTest
{
    my $fileName = $_;

    # Need the $ end of line anchor to reject .v~
    if ($fileName =~ m/testcase.v$/)
    {
        debugPrint("Adding $fileName to testArray\n");
        unshift(@testArray , $fileName);
        $numTests += 1;
    }
}


################################################################################
# Build list of regression directories using argRegressFile filename
#
sub regressFileRead
{

    my $hwRoot = $ENV{'HWROOT'};
    my $currLine;
    my $lineNum = 0;


    open (REG_FILE, "<", "$argRegressFile") 
        or die ("[ERROR] Can't open regression filelist $argRegressFile");
    
    while (<REG_FILE>)
    {
        chomp;
        $currLine = "$_";
        $lineNum += 1;

        debugPrint("REGRESS : Read $currLine \n");

        # Comment line, don't add to array, don't increment number of reg dirs
        if ($currLine =~ m#^//#)
        {
            debugPrint("REGRESS : Comment on line $lineNum - $currLine\n");
        }
        # Ignore empty lines
        elsif ($currLine eq "")
        {
            debugPrint("REGRESS : Empty line # $lineNum - $currLine\n");
        }
        # Die if the current line doesn't contain sim
        elsif (!($currLine =~ m/sim/))
        {
            die ("[ERROR] Line $lineNum ($currLine) doesn't contain sim directory");
        }
        # Not a comment, replace any $ABC with $ENV{'ABC'}
        else
        {
            $currLine =~ s#^\$HWROOT#$hwRoot#;

            if (-d "$currLine")
            {
                infoPrint("Adding $currLine to regression list\n");
                unshift(@regressDirs, $currLine);
                $numRegDirs += 1;
            }
            # Not comment, but a directory that doesn't exist
            else
            {
                die ("[ERROR] Directory $currLine doesn't exist (line  in $currLine in $argRegressFile)");
            }

        }
    }

    close(REG_FILE);

# If the file exists, but there are no lines in there, die
    if (0 == $numRegDirs)
    {
        die ("[ERROR] No simulation directories found in $argRegressFile");
    }

    print("\n");

}




################################################################################
# Sub to clean up temporary files before sim for a clean start
#
sub cleanDir
{

# Plan later is to remove any files which aren't in Perforce.
# For the time being, just delete the work library

    my @cleanFileList;
    my $currCleanFile;

    @cleanFileList = <*>;

    foreach $currCleanFile (@cleanFileList)
    {
        if (    ($currCleanFile =~ m/.\.v$/)
             || ($currCleanFile =~ m/.\.sv$/)
             || ($currCleanFile =~ m/.\.s$/)
             || ($currCleanFile =~ m/.\.do$/)
             || ($currCleanFile =~ m/.\.ref$/)
             || ($currCleanFile =~ m/.\.par$/)
             || ($currCleanFile =~ m/.\.rgb$/)
             || ($currCleanFile =~ m/.\.BIN$/)
             || ($currCleanFile =~ m/.\.trc$/)
             || ($currCleanFile =~ m/frame_ref\.ppm/)
                )
        {
            debugPrint("Not removing $currCleanFile\n");
        }
        else
        {
            debugPrint("Deleting $currCleanFile\n");
            if (!$rsimDebug) {unlink($currCleanFile)}
        }
    }
        
    infoPrint("Removing Modelsim work library\n");
    rmtree('work');
    systemWrap("vlib work");        

#    my $cleanTest = dirname($_[0]);
#    my @cleanFileList;
#    my $cleanFile;
#
#    my $p4ReturnVal;
#
#    print("\n");
#    infoPrint("Cleaning directory $cleanTest\n");
#    
#    @cleanFileList = <*>;
#
#    foreach $cleanFile (@cleanFileList)
#    {
#        $p4ReturnVal = `p4 files $cleanFile`;
#
#        debugPrint("cleanFile = $cleanFile, p4ReturnVal = $p4ReturnVal \n");
#
#        if ($p4ReturnVal =~ m/no such file/)
#        {
#            debugPrint("Would have deleted $cleanFile\n");
#        }
#
#    }
#
#
}


################################################################################
# Sub to compile the assembly testcase.s prior to simulation
#
sub asmCompile
{
    my $returnVal;

    print("\n");
    infoPrint("Compiling assembly test .. \n");

    # non-zero return value means error. SystemWrap handles this case.

    systemWrap("$cmdAs testcase.s -o testcase.o");
    systemWrap("$cmdDump testcase.o > testcase.lst");
    systemWrap("$cmdCopy testcase.o testcase.srec");
    systemWrap("srec_cat testcase.srec -Motorola -Output testcase.hex -VMem 8");
    systemWrap("$cmdHexToRom testcase.hex testcase_rom.v");
}


################################################################################
# Sub to compile the DPI C Reference models
#
# If the test uses a DPI C model in the testbench, need to:
#   1. Generate testcase.h header from TB verilog 
#   2. Compile all c files in the dpi_filelist.c
#   3. Link all C files into a shared object library
#   4. Add an argument to the vsim command to use sv_lib
sub dpiCompile
{
    my $returnVal;
#    my $dpiFile;
    my @dpiSrcArray;
    my $currLine;
    my $lineNum = 0;
    my $dpiCCArgs;
    my $dpiSrc;
    my $dpiCmd;

    print("\n");
    infoPrint("Compiling DPI testbench code .. ");
    
# 1 - Compile testcase.h
    $returnVal = systemWrap("vlog -sv -dpiheader testcase.h -f $tbDir/filelist.lst");
    if ($rsimDebug) {debugPrint("DPIHDR  : Return value = $returnVal\n") }
    
# 2 - Compile list of C files and compile them
    open (DPI_FILE, "<", "$simDir/dpi_filelist.lst")
        or die ("Can't open $simDir/dpi_filelist.lst\n");
    
# Build the dpiSrcArray with C filenames without the .c on the end
    while (<DPI_FILE>)
    {
        chomp;
        $currLine = "$_";
        $lineNum += 1;

        if ($currLine =~ m#^//#)
        {
            debugPrint("DPILST  : Comment on line $lineNum - $currLine\n");
        }
        else
        {
            # Take the .c off so it can be used for .o and .so later
            $currLine =~ s/\.c//;
            unshift(@dpiSrcArray, $currLine);
        }
    }
    
# Build and execute the CC command using the dpiSrcArray (and adding .c on to end)
    $dpiCmd = $dpiCC;

    foreach $dpiSrc (@dpiSrcArray)
    {
        $dpiCmd =  $dpiCmd . " $dpiSrc.c ";
    }
    systemWrap("$dpiCmd");

# Now link all the object files into a shared .so

    $dpiCmd = "$dpiLD $dpiSo.so";

    foreach $dpiSrc (@dpiSrcArray)
    {
        $dpiCmd =  $dpiCmd . " " . basename("$dpiSrc") . ".o";
    }
    systemWrap("$dpiCmd");

# And add on the library to the vsim argument
    
    if (!($vsimFlags =~ m/-sv_lib/))
    {
        $vsimFlags = $vsimFlags . "-sv_lib $dpiSo";
    }   

    close(DPI_FILE);

}

################################################################################
# Sub to modify the vlog and vsim commands which apply to all tests
#
sub modelsimFlags
{

    $vlogFlags = $baseVlogFlags;
    $vsimFlags = $baseVsimFlags;

    if ($argDump)
    {
        $vsimFlags = $vsimFlags . '-novopt -debugDB=vsim.dbg -wlf vsim.wlf -do "add log -r /* ; run -all" ';
    }
    # Don't run the sim straight away if you're running a GUI !
    elsif (!$argGui)
    {
        $vsimFlags = $vsimFlags . '-do "run -all" ';
    }
    
    $vsimFlags = $vsimFlags . "-sv_seed $argSeed ";

    if ($argCover)
    {
        $vlogFlags = $vlogFlags . " +cover "
    }

    if ($argGui)
    {
        $vsimFlags = $vsimFlags . " -i ";
    }
    else
    {
        $vsimFlags = $vsimFlags . " -c ";
    }



}

################################################################################
# Sub to check the transcript to see if the test passed or not. unshifts result
# into the testResultArray
#
sub checkSim
{

    my $currTest = $_[0];

    my $currLine;
    my $lineNum ;

    my $testFail = 0; # Did the test definitely fail?
    my $testPass = 0; # Did the test definitely pass?
    my $testString;

    $lineNum = 0;

    open (VLOG_FILE, "<", "vlog.log") or die ("Can't open vlog.log\n");
    while (<VLOG_FILE>)
    {
        chomp;
        $currLine = "$_";
        $lineNum += 1;

        if ($currLine =~ m/ERROR/i) # i means case insensitive
        {
            debugPrint("CHKSIM : ERROR in vlog log :  $currLine, FAIL\n");
            $testFail = 1;
        }

    }

    open (SIM_FILE, "<", "vsim.log") or die ("Can't open vsim.log\n");
    
    $lineNum = 0;

    while (<SIM_FILE>)
    {
        chomp;
        $currLine = "$_";
        $lineNum += 1;

        if ($currLine =~ m/ERROR/i) # i means case insensitive
        {
            debugPrint("CHKSIM : ERROR found on line $currLine, FAIL\n");
            $testFail = 1;
        }
        elsif ($currLine =~ m/FAIL/i) # i means case insensitive
        {
            debugPrint("CHKSIM : FAIL  found on line $currLine, FAIL\n");
            $testFail = 1;
        }
        elsif ($currLine =~ m/PASS/i) # i means case insensitive
        {
            debugPrint("CHKSIM : PASS  found on line $currLine, PASS !\n");
            $testPass = 1;
        }
    }
    

    # 1st priority - if any fails or errors were found anywhere it FAILED
    if ($testFail)
    {
        $testString = 'FAIL';
    }
    # 2nd priority - if no fails or errors were found, but a PASS was found, it passed
    elsif ($testPass)
    {
        $testString = 'PASS'
    }
    else
    {
        $testString = 'FAIL';
    }


    debugPrint("CHKSIM : testPass = $testString, adding to result array\n");
    unshift(@testResultArray, $testString);

    # Store the result in an associative array, indexed using test name as key
    $testAssocArray{"$currTest"} = $testString;

    debugPrint("CHKSIM : Final check for Test $currTest, Result = $testString \n");

    close(SIM_FILE);

}


################################################################################
# Sub to report all the simulation test results
#
sub reportSims
{

    my $testName;
    my $testResult;
    my $numTests;

    my $testLoop;

    $endTime = time;
    $scriptTime = $endTime - $startTime;

    $numTests = $#testArray + 1;

    infoPrint("\n");
    infoPrint("################################################################################\n");
    infoPrint(sprintf("Test Results (Running time: %02d:%02d:%02d)\n", int($scriptTime / 3600), int(($scriptTime % 3600) / 60), int($scriptTime % 60)));
    infoPrint("Total # tests = $numTests\n");
    infoPrint("\n");
    infoPrint("|------------------------------------------------------------------------------|\n");
    infoPrint("| Test Name                                                   | Test Result    |\n");
    infoPrint("|------------------------------------------------------------------------------|\n");

    while ($#testResultArray + 1)
    {
        $testName   = shift(@testArray);
        $testResult = pop(@testResultArray); # todo ! Why do you need to reverse this order??

        # Remove all the simulation string up to /sim
        $testName =~ s#^.+hwdev/##;
        # Remove the testcase.v
        $testName = dirname($testName);

        infoPrint(sprintf("| %-59s | %-14s |\n", $testName, $testResult));

    }
    infoPrint("|------------------------------------------------------------------------------|\n");
    infoPrint("\n");
    infoPrint("################################################################################\n");

}

################################################################################
# Main Program 


# Process the input arguments
$argRetVal = GetOptions (
    # Valid options
    'noclean'   => \$argNoClean  ,
    'def=s'     => \$argDef    ,
    'dump'      => \$argDump   ,
    'do=s'      => \$argDo     ,
    'cover'     => \$argCover  ,
    'gui'       => \$argGui    ,
    'seed=s'    => \$argSeed   ,
    # Help options
    'h'         => \$argH      ,
    'help'      => \$argHelp   ,
    # RSIM script debuggin option
    'debug'     => \$rsimDebug ,
    'regress=s' => \$argRegressFile
    );


debugPrint("Return Val      = $argRetVal  \n");
debugPrint("argNoClean      = $argNoClean \n");
debugPrint("argDef          = $argDef     \n");
debugPrint("argDump         = $argDump    \n");
debugPrint("argDo           = $argDo      \n");
debugPrint("argCover        = $argCover   \n");
debugPrint("argGui          = $argGui     \n");
debugPrint("argSeed         = $argSeed    \n");
debugPrint("argH            = $argH       \n");
debugPrint("argHelp         = $argHelp    \n");
debugPrint("rsimDebug       = $rsimDebug  \n");
debugPrint("argRegressFile  = $argRegressFile \n");

if ($argH || $argHelp)
{
    print $helpInfo;
    exit;
}

# If you're not in regress mode, just search for tests under calling directory
if ($argRegressFile eq "")
{
    # Setup the directories to be used in the current test
    $callDir = Cwd::abs_path;
#    $simDir = $callDir;
#    $simDir =~ s#sim.+$#sim#;
#    $tbDir  = $simDir;
#    $tbDir  =~ s#sim#tb#;
#
#    debugPrint("callDir = $callDir\n");
#    debugPrint("simDir  = $simDir\n");
#    debugPrint("tbDir   = $tbDir\n");

    infoPrint("Searching for tests in current directory and below .. \n");
    print("\n");
    
    # Find all directories with a testcase.v in them
    find({wanted => \&addTest, no_chdir => 1}, $callDir);

    die "\n[ERROR] Run at 'sim' directory or below\n" unless ($callDir =~ m/sim/);

}
else
{
    # Populates @regressDirs with a list of directories to step through
    regressFileRead;

    # callDir is the caling directory (regression dir for regressions)
    $callDir = Cwd::abs_path;

    foreach $currRegressDir (@regressDirs)
    {
        infoPrint("Searching for tests under $currRegressDir .. \n");
        
        # Find all directories with a testcase.v in them
        find({wanted => \&addTest, no_chdir => 1}, $currRegressDir);

        print("\n");
    }


}


# If no tests are found, drop out of the script
if (0 == $numTests)
{
    errorPrint("No tests found under current directory");
}

# Otherwise list the tests and run each of them
else
{
    
    # Sort tests alphabetically
    @testArray = sort(@testArray);

    # Print out a list of tests
    print("\n");
    infoPrint("Found $numTests test(s):\n");
    print join("\n",@testArray), "\n";
    print("\n");

    # Main Test Loop.
    # Calling directory already saved in $callDir
    foreach $currTest (@testArray)
    {
        infoPrint("Running $currTest\n");
    
        # Reset the flags according to the arguments 
        # This will also remove the DPI linking stage if it isn't required
        modelsimFlags;

        # Setup directories
        $simDir = dirname($currTest);
        $simDir =~ s#sim.+$#sim#;
        $tbDir  = $simDir;
        $tbDir  =~ s#sim#tb#;

        debugPrint("callDir = $callDir\n");
        debugPrint("simDir  = $simDir\n");
        debugPrint("tbDir   = $tbDir\n");

        chdir(dirname($currTest));
        debugPrint("Changing directory to " . dirname($currTest) . "\n");

        if (!$argNoClean) { cleanDir($currTest) };
        
        if (-e 'testcase.s') { asmCompile };

        if (-e "$simDir/dpi_filelist.lst") { dpiCompile };

        systemWrap("vlog  $vlogFlags -f $simDir/filelist.lst | tee vlog.log");
        systemWrap("vsim  $vsimFlags TB_TOP | tee vsim.log");

        infoPrint("\n");
        
        checkSim($currTest);
    }

    reportSims;
}

chdir($callDir);



################################################################################

