# Makefile.PL for Dbf2pdf build
# Copyright (c) 2001   Andrew Orr 
# See COPYRIGHT section in Dbf2pdf.pm for usage and distribution rights.

use ExtUtils::MakeMaker;
use Getopt::Long;

my $default_temp_dir = "tmp";
my $temp_dir = "";

### CHECK FOR REQUIRED MODULES ################################################
#eval "use Report";  # The wrapper
#if (length($@)) {
#  print "$@\n"; exit;
#} 
eval "use XBase";   # DBF Handler
if (length($@)) {    
  print "$@\n"; exit;
}

### IF THE USER WANTS TO SPECIFY A DIFFERENT DIRECTORY ########################
&GetOptions("TEMP_DIR=s" => \$temp_dir);

$file = "Dbf2pdf.pm";
$old = $file;
$new = "$file.tmp.$$";
$bak = "$file.orig";

if ($temp_dir !~ /\/?$default_temp_dir/ and $temp_dir ne "") {
  print "here\n"; exit;
  open(OLD, "< $old")
    or die "Couldn't open file for reading: $!\n";
  open(NEW, "> $new")
    or die "can't open $new: $!";

  while (<OLD>) {
    s/\/$default_temp_dir/$temp_dir/g;
    print NEW $_;
     if ($_ =~ s/\/$default_temp_dir/$temp_dir/g) {
       print "matched & replaced!\n";
     }
  }
  close(OLD) or die "can't close $old: $!";
  close(NEW) or die "can't close $new: $!";
 
  rename($old, $bak) or die "can't rename $old to $bak: $!";
  rename($new, $old) or die "can't rename $new to $old: $!";
}
###############################################################################

### CREATE THE MAKEFILE ##########
WriteMakefile( NAME => "Data::Dbf2pdf",
               VERSION => "0.7" );

# End
