###############################################################################
# DBF to PDF Format Conversion Package for Perl.
# Copyright (C) 2001, Andy Orr <aorr@TheAIMSGroup.com>
###############################################################################

package Data::Dbf2pdf;
require 5.000;
require Exporter;
use Carp;
use Data::Data2PdfReport;
use XBase;

@ISA = qw(Exporter);
@EXPORT = qw(dbf2pdf);

# Man Page ####################################################################

=head1 NAME

Dbf2pdf - Converts DBF file format to PDF format

=head1 SYNOPSIS

=item use Dbf2pdf;

=item &dbf2pdf($PageSize,$PageOrientation,$DbfFile,$PdfFile,$FontSize,$Title);

=head1 DESCRIPTION

Convert a DBF file to Portable Document Format.  The arguments that it 
takes are described below:

	$PageSize:        	letter (default), legal, tabloid
        $PageOrientation: 	Portrait (default), Landscape
        $DbfFile:         	Input DBF file location (required)
        $PdfFile:         	Output PDF file location (optional)
        $FontSize:        	Desired size of font  (optional, default '10')
        $Title:                 String centered at top of first page (optional)

If no output file is specified the pdf data is printed to STDOUT. 

=head1 LICENSE

A license is hereby granted for anyone to reuse this Perl module in
its original, unaltered form for any purpose, including any commercial
software endeavor.  However, any modifications to this code or any
derivative work (including ports to other languages) must be submitted
to the original author, Andy Orr, before the modified
software or derivative work is used in any commercial application.
All modifications or derivative works must be submitted to the author
with 30 days of completion.  The author reserves the right to
incorporate any modifications or derivative work into future releases
of this software.

This software cannot be placed on a CD-ROM or similar media for
commercial distribution without the prior approval of the author.

=cut
###############################################################################

$VERSION = "0.7";

###############################################################################
# Public Function #############################################################
###############################################################################
sub dbf2pdf {
  my $page_size        = shift(@_);
  my $page_orientation = shift(@_);
  my $infile           = shift(@_);
  my $outfile          = shift(@_);
  my $fontsize         = shift(@_);
  my $title            = shift(@_);

  ### SET DEFAULTS FOR PASSED VARS, WHERE NEEDED ###############
  $page_size = 'letter' if !length($page_size);                 
  $page_orientation = 'Landscape' if !length($page_orientation);
  die "No input file given: $!\n" if !length($infile);          
  $FONTSIZE = 10 if !length($FONTSIZE);
  $outfile = undef if !length($outfile);

  # Instantiate XBase object, handle invalid DBF file
  $table = new XBase("name"=>$infile) or die XBase->errstr;

  ### GET VALUES FOR THE DBF ################
  @dbf_fld_names=$table->field_names();
  @dbf_fld_types=$table->field_types();
  @dbf_fld_lengths=$table->field_lengths();
  @dbf_fld_decimals=$table->field_decimals();

  my @Data;

  for (0 .. $table->last_record) {
    my %hash = $table->get_record_as_hash($_);
    push @Data, { %hash };
  } 
  
  # Format the data according to type
  FormatData(\@Data, ,\@dbf_fld_names, \@dbf_fld_types); 

  data2pdf(\@Data, \@dbf_fld_names, $page_size, $page_orientation,
                                     $outfile, $fontsize, $title);

#  print STDERR;  # Debug

}
### END PUBLIC ################################################################

###############################################################################
# Private Functions ###########################################################
###############################################################################
sub FormatData {
  my $rData  = shift;
  my $rNames = shift;
  my $rTypes = shift;

  # Loop through all the data 
  for (0 .. $#{ $rData }) {
    for($i = 0; $i <= $#{ $rTypes }; $i++) {
      if ($rTypes->[$i] eq 'D') {  # Format date
        $rData->[$_]{$rNames->[$i]} 
          = PrettyPrintDate($rData->[$_]{$rNames->[$i]});
      }
#      if ($rTypes->[$i] eq 'T') {  # Format time
#         
#      }
    } 
  }
}

sub PrettyPrintDate {  # THIS ONLY SUPPORTS "MM/DD/YYYY" from YYYYMMDD !!
  my($Date)   = shift(@_);
  my($Seprtr) = shift(@_);

  my($y,$m,$d);
  if (length($Date) == 8) {
    $y=substr($Date,0,4);
    $m=substr($Date,4,2);
    $d=substr($Date,6,2);
    if (!length($Seprtr) or $Seprtr eq 'slash')  {
      return sprintf("%02d/%02d/%04d", $m,$d,$y);
    } elsif ($Seprtr eq 'dash') {
      return sprintf("%02d-%02d-%04d", $m,$d,$y);
    }
  } 
  return $Date;  # If the date's not in the right format return it
}

1;
