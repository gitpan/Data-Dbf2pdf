###############################################################################
# Hacked up code to put array of hashes into pdf form.
# Copyright (C) 2001, Andy Orr <aorr@TheAIMSGroup.com>
###############################################################################

package Data::Data2PdfReport;
require 5.000;
require Exporter;
use Carp;
use Data::Report;

@ISA = qw(Exporter);
@EXPORT = qw(data2pdf);

$VERSION = "0.1";  

###############################################################################
# Private Module-global Variables #############################################
###############################################################################
my $INIT_COL = 0;
my $FONTSIZE;
my $ROWHEIGHT; 
my $TEXTSIZE;
my $MASTERX1; 
my $MASTERX2;
my $MASTERY1;
my $MASTERY2;
my $SPACER;
my $MAXCHARS;
my $MAXROWS;
my $PDF;
my $DREF;
my $R_HDR_ORDR;

my @DBF_FLD_NAMES;
my @DBF_FLD_TYPES;
my @DBF_FLD_LENGTHS;
my @DBF_FLD_DECIMALS;
my %FIELD_LENGTH;

###############################################################################
# Public Function #############################################################
###############################################################################
sub data2pdf {
  $DREF                = shift(@_);
  $R_HDR_ORDR          = shift(@_);
  my $page_size        = shift(@_);
  my $page_orientation = shift(@_);
  my $outfile          = shift(@_);
  $FONTSIZE            = shift(@_);
  my $title            = shift(@_);

  my $page_count = 0;
  my $tmp_dir = "/tmp";  # THIS CAN BE CHANGED 

  ### SET DEFAULTS FOR PASSED VARS, WHERE NEEDED ################
  $page_size = 'letter' if !length($page_size);                 #
  $page_orientation = 'Landscape' if !length($page_orientation);#
  $FONTSIZE = 10 if !length($FONTSIZE);
  ###############################################               #
  # Outfile is handled below if not initialized #               #
  ############################################################### 

  # Instantiate PDF object
  $PDF   = new Data::Report('PageSize' => $page_size,
                      'PageOrientation' => $page_orientation);

  # Get the page dimensions, dependent on the page size
  my ($pagewidth,$pageheight)=@{$Text::PDF::API::pagesizes{$page_size}};

  # Reverse the values for landscape
  if (lc($page_orientation) =~ m/landscape/) {
    my $tmp=$pagewidth;  $pagewidth=$pageheight;  $pageheight=$tmp;
  }

  my $margin = 35;
  my $max = $pagewidth - (2 * $margin);  ### SUBTRACT MARGINS FROM WIDTH

  #############################################################################
  ## SET GLOBAL PDF ENVIRONMENT SETTINGS ######################################
  #############################################################################
  $PDF->setFont('Courier');
  $PDF->setSize($FONTSIZE);
  $ROWHEIGHT = int($FONTSIZE * 1.20);
  $TEXTSIZE = $PDF->{pdf}->calcTextWidth('M');
  my $PageHeight = ($pageheight - 2 * $margin);
  $k = $PageHeight % $ROWHEIGHT;
  $PageHeight-=$k;
  $MASTERX1 = $margin;    # LEFT 
  $MASTERX2 = $pagewidth - $margin;   # RIGHT
  $MASTERY1 = $PageHeight + $margin;   # TOP
  $MASTERY2 = $margin;    # BOTTOM
  $SPACER = $TEXTSIZE;
  $MAXCHARS = int($max / $TEXTSIZE);
  while ($PageHeight % $ROWHEIGHT) {
    $ROWHEIGHT++; 
  } 
  $MAXROWS = int($PageHeight / $ROWHEIGHT); 
  my $first_col;
  my $last_col;
  #############################################################################


  # GRAB THE HEADERS 
  @DBF_FLD_NAMES = @$R_HDR_ORDR;

  # GET THE COLUMN WIDTHS
  for ( 0 .. $#{ $DREF } ) {
    for ($i = 0; $i <= $#{ $R_HDR_ORDR }; $i++) {
      if (length($R_HDR_ORDR->[$i]) > $DBF_FLD_LENGTHS[$i]) {
        $DBF_FLD_LENGTHS[$i] = length($R_HDR_ORDR->[$i]);
      } 
      if (length($DREF->[$_]{$R_HDR_ORDR->[$i]}) > $DBF_FLD_LENGTHS[$i]) {
        $DBF_FLD_LENGTHS[$i] = length($DREF->[$_]{$R_HDR_ORDR->[$i]});
      } 
    }
  } 

  $last_col = &GetNbrCols($INIT_COL);       # Set last column
  $first_col = $last_col + 1;               # Set first column of next page set

  while ($last_col <= $#DBF_FLD_LENGTHS ) { # Loop over all DBF records
    $PDF->newpage();
#    $PDF->addImg("/home/aorr/image_storage/raildocs_watermark_orig.gif", 274, 264);
    if (!$page_count++ and length($title)) {
      $PDF->setFont('Courier-Bold');                         
      $PDF->setSize(10) if $FONTSIZE < 10;
      &CenterString($MASTERX1,$MASTERX2,$MASTERY1+(12+$SPACER),$title);
      $PDF->setFont('Courier');
      $PDF->setSize($FONTSIZE) if $FONTSIZE < 10;
    }
    &PrintHeaders($last_col,$INIT_COL);
    &PrintFieldData($last_col,$ROWHEIGHT);
    if ($last_col >= $#DBF_FLD_LENGTHS) { last; }
    $INIT_COL = $first_col;
    $last_col = &GetNbrCols($INIT_COL);
    $first_col = $last_col + 1;
  }
  if (length($outfile)) {
    open(OUT, ">$outfile") 
        or croak "Error opening $outfile";
    print OUT $PDF->Finish(0);
    close OUT;
  } else {
    print $PDF->Finish(0); 
  }
}
### END PUBLIC ################################################################

###############################################################################
# Private Functions ###########################################################
###############################################################################
sub DrawPageLines {
  my $last    = shift;
  my $RHeight = shift;
  my $Rows    = shift; 

  #### OUTLINE #################################################
  $PDF->drawLine($MASTERX1,$MASTERY1+12,$MASTERX2,$MASTERY1+12);
  $PDF->drawLine($MASTERX1,$MASTERY1+12,$MASTERX1,$MASTERY2);
  $PDF->drawLine($MASTERX1,$MASTERY2,$MASTERX2,$MASTERY2);
  $PDF->drawLine($MASTERX2,$MASTERY1+12,$MASTERX2,$MASTERY2);
  ##############################################################
 
  my $HorX1 = $MASTERX1;
  my $HorY = $MASTERY1;
  my $HorX2 = $MASTERX2;

  my $VertX = $MASTERX1;
  my $VertY1 = $MASTERY1+12;
  my $VertY2 = $MASTERY2;

  if (!$Rows) {
    while ($HorY > $MASTERY2) {
      $PDF->drawLine($HorX1,$HorY,$HorX2,$HorY);
      $HorY-=$RHeight;
    }
    for (my $i=$INIT_COL; $i<$last; $i++) {
      $VertX+=$FIELD_LENGTH{$DBF_FLD_NAMES[$i]} + ($SPACER*2);  
      $PDF->drawLine($VertX,$VertY1,$VertX,$VertY2);
    }
  } 
}

sub PrintHeaders {
  my $last  = shift;
  my $first = shift;

  my $X = $MASTERX1;
  my $Y = $MASTERY1 + 2;
  my $FieldName;
  my $offset;

  $PDF->setFont('Courier-Bold');
  
  if (!$first) {
    for (my $i=0; $i<=$last; $i++) {
      $offset = ($FIELD_LENGTH{$DBF_FLD_NAMES[$i]}/$TEXTSIZE);
      $FieldName = substr($DBF_FLD_NAMES[$i],0,$offset);
      $PDF->addRawText($FieldName,$X + $SPACER,$Y);
      $X+=$FIELD_LENGTH{$DBF_FLD_NAMES[$i]} + ($SPACER*2);
    }
  } else {
    for (my $i=$first; $i<=$last; $i++) {
      $offset = ($FIELD_LENGTH{$DBF_FLD_NAMES[$i]}/$TEXTSIZE);
      $FieldName = substr($DBF_FLD_NAMES[$i],0,$offset);
      $PDF->addRawText($FieldName,$X + $SPACER,$Y);
      $X+=$FIELD_LENGTH{$DBF_FLD_NAMES[$i]} + ($SPACER*2);
    }
  }
  $PDF->setFont('Courier');
}

sub PrintFieldData {
  my $last    = shift;
  my $RHeight = shift;

  my $Y = $MASTERY1 - $ROWHEIGHT + 2; 

  &DrawPageLines($last,$ROWHEIGHT,0);
  my $rCnt = 1;
  for (0 .. $#{ $DREF }) {
    if ($rCnt++ > $MAXROWS) {
      $rCnt = 2;
      $PDF->newpage();
      &PrintHeaders($last,$INIT_COL);
      &DrawPageLines($last,$ROWHEIGHT,0);
      $Y = $MASTERY1 - $ROWHEIGHT + 2;
    }  
    my $fld;
    my $X = $MASTERX1;
    for (my $col = $INIT_COL; $col <= $last; $col++) {
      $PDF->addRawText($DREF->[$_]{$DBF_FLD_NAMES[$col]},$X+$SPACER,$Y);
      $X+=$FIELD_LENGTH{$DBF_FLD_NAMES[$col]} + ($SPACER*2); 
    }
    $Y-=$ROWHEIGHT;
  }
}

sub GetNbrCols {
  my $first = shift;
  my $last  = 0;
  my $chars = 0;
  my $local_field_length = 0;
  my $tmp = 0;
  
  for (my $i=$first; $i <= $#DBF_FLD_LENGTHS; $i++) {
    $local_field_length = $DBF_FLD_LENGTHS[$i];
    if ($local_field_length < (length($DBF_FLD_NAMES[$i]) + 1)) {
      $local_field_length = length($DBF_FLD_NAMES[$i]) + 1;
    } 
    $tmp = $chars;
    $chars+=$local_field_length + 2; 
    if ($local_field_length >= $MAXCHARS) {
      $FIELD_LENGTH{$DBF_FLD_NAMES[$i]} = int($TEXTSIZE * $MAXCHARS);
      if ($tmp) {
        $last = $i - 1; 
      } else {
        $last = $i;
      }
      last;  
    } elsif ($chars >= $MAXCHARS) {
      $FIELD_LENGTH{$DBF_FLD_NAMES[$i]} = int($TEXTSIZE * $local_field_length);
      $last = $i - 1;
      last;
    } else {
      $FIELD_LENGTH{$DBF_FLD_NAMES[$i]} = int($TEXTSIZE * $local_field_length); 
      $last = $i;
    }
    $tmp = 0;
  }
  return $last; 
}

sub PrettyPrintDate {
  my($Date) = shift(@_);

  my($y,$m,$d);
  if (length($Date) == 8) {
    $y=substr($Date,0,4);
    $m=substr($Date,4,2);
    $d=substr($Date,6,2);
    return sprintf("%02d/%02d/%04d", $m,$d,$y);
  } 
  return $Date;  # If the date's not in the right format return it
}

sub CenterString {  ### CENTERS STRING BETWEEN TWO POINTS
  my $PointBegin = shift;
  my $PointEnd = shift;
  my $YPos = shift;
  my $String = shift;

  my $OldTextSize = $PDF->getSize;
  my $TextSize = $OldTextSize;

  my $Area = $PointEnd - $PointBegin;

  while (($StringWidth = &GetStringWidth($String)) > $Area) {
    $PDF->setSize(--$TextSize);  ### DECREASE THE FONTSIZE TO MAKE IT FIT
  }

  my $Offset = ($Area - $StringWidth) / 2;
  $PDF->addRawText("$String",$PointBegin+$Offset,$YPos);
  $PDF->setSize($OldTextSize);  # Reset the size
}

sub GetStringWidth {
  my $String = shift;
  my $StringWidth = 0;

  # GET PT LENGTH OF EACH CHARACTER IN STRING
  # DONE THIS WAY TO HANDLE VARIABLE WIDTH FONT
  while ($String =~ /(.)/g) {
    $StringWidth+=$PDF->{pdf}->calcTextWidth($1);
  }
  return $StringWidth;
}

1;
