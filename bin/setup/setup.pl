#!/usr/bin/env perl

use CPAN;
use File::Which;  die "You do not have File::Which installed.\n Run perl -MCPAN -e 'install File::Which' to install. Then rerun this." if $@;
use Cwd;

sub promptUser {

   #-------------------------------------------------------------------#
   #  two possible input arguments - $promptString, and $defaultValue  #
   #  make the input arguments local variables.                        #
   #-------------------------------------------------------------------#

   local($promptString,$defaultValue) = @_;

   #-------------------------------------------------------------------#
   #  if there is a default value, use the first print statement; if   #
   #  no default is provided, print the second string.                 #
   #-------------------------------------------------------------------#

   if ($defaultValue) {
      print $promptString, "[", $defaultValue, "]: ";
   } else {
      print $promptString, ": ";
   }

   $| = 1;               # force a flush after our print
   $_ = <STDIN>;         # get the input from STDIN (presumably the keyboard)


   #------------------------------------------------------------------#
   # remove the newline character from the end of the input the user  #
   # gave us.                                                         #
   #------------------------------------------------------------------#

   chomp;

   #-----------------------------------------------------------------#
   #  if we had a $default value, and the user gave us input, then   #
   #  return the input; if we had a default, and they gave us no     #
   #  no input, return the $defaultValue.                            #
   #                                                                 #
   #  if we did not have a default value, then just return whatever  #
   #  the user gave us.  if they just hit the <enter> key,           #
   #  the calling routine will have to deal with that.               #
   #-----------------------------------------------------------------#

   if ("$defaultValue") {
      return $_ ? $_ : $defaultValue;    # return $_ if it has a value
   } else {
      return $_;
   }
}

sub getListModules {
    my @cpanModules;
    print "Finding Installed CPAN Modules.\n";
    for $mod (CPAN::Shell->expand("Module","/./")){
        next unless $mod->inst_file;
        # here only when installed
        #get the module
        my $modname = $mod->id;
        push(@cpanModules,$modname);
        print ".";
    }
    print "Done\n";
    return @cpanModules;
}

sub moduleExists {
    my ($searchModule,@cpanModules) = @_;
    foreach(@cpanModules) {
        if($_ eq $searchModule) {
            return 1;
        }
    }
    return 0;
}

sub moduleInstaller {
    my(@modulesNeeded) = @_;
    my @moduleList = getListModules;
    my @manuallyNeeded;
    foreach(@modulesNeeded) {
        my $needed = $_;
        if(moduleExists($needed,@moduleList) == 0) {
            push(@manuallyNeeded,$needed);
        } else {
            print "Found $needed \n";
        }
    }
    return @manuallyNeeded;
}

sub programPath {
    my($program) = @_;
    $path = which($program);
    if($path != 0) {
        $enteredPath = promptUser("Enter the path to '$program'");
    } else {
        $enteredPath = promptUser("Enter the path to '$program'",$path);
    }
    return $enteredPath;
}



print "###################################\n";
print "#WeBWorK Question Server          #\n";
print "###################################\n";

#Continue?
print "This script will setup the WeBWorK Question Server.\n";
$continue = promptUser('Continue','y');
if($continue ne "y") {
    exit;
}

#Apache Version
$question = "Which version of Apache";
$result = which('apache2ctl');
if($result != 0) {
    $result = which('apachectl');
    if($result != 0) {
        $apacheVersion = promptUser("$question(1,2)");
    } else {
        $apacheVersion = promptUser("$question(1,2)",'1');
    }
} else {
    $apacheVersion = promptUser("$question(1,2)",'2');
}
if($apacheVersion eq '1') {
    $apacheSoapCPAN = "Apache::SOAP";
    $modperlCPAN = 'mod_perl';
} elsif ($apacheVersion eq '2') {
    $apacheSoapCPAN = "Apache2::SOAP";
    $modperlCPAN = 'mod_perl2';
} else {
    exit;
}


#CPAN Module Administration
$preqCheck = promptUser("Check CPAN Prerequisites(y,n)",'y');
if($preqCheck eq 'y') {
    @modulesNeeded = ($modperlCPAN,$apacheSoapCPAN,'LWP::Simple','Pod::WSDL','Safe','MIME::Base64','File::Which','GD');
    @manuallyNeeded = moduleInstaller(@modulesNeeded);

    $manuallyNeededCount = @manuallyNeeded;
    if($manuallyNeededCount == 0) {
        print "All CPAN Modules are Installed!\n";
    } else {
        print "Install the following CPAN Modules and rerun this script.\n";
        foreach(@manuallyNeeded) {
            print "$_\n";
        }
        exit;
    }
}

#Programs
$latex = programPath('latex');
$dvipng = programPath('dvipng');
$tth = programPath('tth');

#Configuration
#HOSTNAME
$hostnameExample = "http://www.example.com/";
print "Please enter the http hostname of the computer.\n";
print "This should be a value like '$hostnameExample'\n";
$hostname = promptUser('');

#Program Root
my $path = $0;
$path =~ s|[^/]*$||;
$path = Cwd::abs_path($path);
$path = $path .  '/../../';
$path = Cwd::abs_path($path);
print "Please enter the root directory where WeBWorK Question Server is located. \n";
print "Example: /var/www/ww_question_server \n";
$root = promptUser('',$path);

print "Please enter the directory where the PG libraries are located. \n";
print "Example: /opt/webwork/pg \n";
$pg = promptUser('');

$rpc = "/problemserver_rpc";
$files = "/problemserver_files";


#WSDL FILE CREATION
use Pod::WSDL;
print "Creating WSDL File...\n";
eval "use lib '$root/lib'"; die "Your root directory is wrong." if $@;
$pod = new Pod::WSDL(
        source => 'ProblemServer',
        location => $hostname.$rpc,
        pretty => 1,
        withDocumentation => 0
        );

$wsdlfilename = "WSDL.wsdl";
open(OUTP, ">$wsdlfilename") or die("Cannot open file '$wsdlfilename' for writing.\n");
print OUTP $pod->WSDL;
close OUTP;
print "Done\n";

#APACHE CONFIGURATION FILE CREATION
print "Creating Apache Configuration File...\n";

$conffilename = "problemserver.apache-config";

print "   Setting Variables...\n";
$additionalconf = "my \$hostname = '$hostname';\n";
$additionalconf .= "my \$root_dir = '$root';\n";
$additionalconf .= "my \$root_pg_dir = '$pg';\n";
$additionalconf .= "my \$rpc_url = '$rpc';\n";
$additionalconf .= "my \$files_url = '$files';\n";
$wsdl = $hostname . $files . '/' . $wsdlfilename;
$additionalconf .= "my \$wsdl_url = '$wsdl';\n";

print "   Loading Base...\n";
open(INPUT, "<problemserver.apache-config.base");
$content = "";
while(<INPUT>)
{
    my($line) = $_;
    $content .= $line;
}
close INPUT;
$content =~ s/MARKER_FOR_CONF/$additionalconf/;
$content =~ s/MARKER_FOR_APACHE/$apacheSoapCPAN/;

print "   Writing...\n";
open(OUTP2, ">$conffilename") or die("Cannot open file '$conffilename' for writing.\n");
print OUTP2 $content;
close OUTP2;
print "Done\n";

#GLOBAL CONFIGURATION FILE CREATION
print "Creating Global Configuration File...\n";

print "   Loading Base...\n";
open(INPUT2, "<global.conf.base");
$content = "";
while(<INPUT2>)
{
    my($line) = $_;
    $content .= $line;
}
close INPUT2;
$content =~ s/MARKER_FOR_DVIPNG/$dvipng/;
$content =~ s/MARKER_FOR_LATEX/$latex/;
$content =~ s/MARKER_FOR_TTH/$tth/;
print "   Writing...\n";
open(OUTP3, ">global.conf") or die("Cannot open file 'global.conf' for writing.\n");
print OUTP3 $content;
close OUTP3;
print "Done\n";

#POST CONFIGURATION
$copyFiles = promptUser('Do you want me to copy created files to their proper locations (y,n)','y');
if($copyFiles eq 'y') {
    system('mv global.conf ' . $root . '/conf/global.conf');
    system('mv problemserver.apache-config ' . $root . '/conf/problemserver.apache-config');
    system('mv WSDL.wsdl ' . $root . '/htdocs/WSDL.wsdl');
}


$dirPerm = promptUser('Do you want me to set directory permissions(requires sudo) (y,n)','y');
if($dirPerm eq 'y') {
   print "Setting Directory Permissions\n";
   system("sudo chmod -R 777 $root/tmp");
   system("sudo chmod -R 777 $root/htdocs/tmp");
   print "Done\n";
}

print "********************************\n";
print "Your WSDL path: '" . $hostname . $files . '/'.$wsdlfilename."'\n";
print "********************************\n";

print "POST INSTALL\n";
$i = 1;
if($copyFiles eq 'n') {
   print "$i) Copy the following files to their respective destinations\n";
   print "global.conf" . '                 => ' . $root . "/conf/global.conf\n";
   print "problemserver.apache-config" . ' => ' .$root . "/conf/problemserver.apache-config\n";
   print "WSDL.wsdl" . '                   => ' . $root . "/htdocs/WSDL.wsdl\n\n";
   $i++;
}

if($dirPerm eq 'n') {
   print "$i) Set the permissions on the following directories so they are read/write accessible by your webserver\n";
   print "$root/tmp\n";
   print "$root/htdocs/tmp\n\n";
   $i++;
}

print "$i) Append the following line to your apache configuration file:\n";
print "Include $root/conf/problemserver.apache-config\n\n";
$i++;

print "$i) Restart Apache\n";

print "Your done, Enjoy!\n";
