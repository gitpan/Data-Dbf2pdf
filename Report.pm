package Data::Report;

use strict;

use Text::PDF::API;

# Sane defaults for the Text::PDF::API object
my %DEFAULTS;
$DEFAULTS{PageSize}='letter';
$DEFAULTS{PageOrientation}='Portrait';
$DEFAULTS{Compression}=1;
$DEFAULTS{PdfVersion}=3;

# These variables will likely go away as I work on this -- LHH
my $pageWidth;
my $pageHeight;

# Fill $PrintDate for use later in this module.  This needs to move
# inside the newpage() method before I'm done with this -- LHH
my ( $day, $month, $year )= ( localtime( time ) )[3..5];
my $PrintDate=sprintf "%02d/%02d/%04d", ++$month, $day, 1900 + $year;

my $MARGINS=25;
my $MARGINX=$MARGINS; my $MARGINY=$MARGINS;
my %Text_PDF_API_DEFAULTS;

# Imported from an older version of Text::PDF::API, supports newest version 
my @parameterlist=qw(
        PageSize
        PageWidth
        PageHeight
        PageOrientation
        Compression
        PdfVersion
);

# Create a new PDF
sub new {
  my $class=shift @_;
  my %defaults=@_;

  # Setup the Text::PDF::API defaults as defined by this module
  foreach my $key (@parameterlist) {
    if (defined($defaults{$key})) {
      $Text_PDF_API_DEFAULTS{$key}=$defaults{$key};  # User's defaults
    } else {
      $Text_PDF_API_DEFAULTS{$key}=$DEFAULTS{$key};  # Default defaults :)
    }
  }
  # If the PageSize is not valid, set it to the DEFAULT value
  if (!defined(
	$Text::PDF::API::pagesizes{$Text_PDF_API_DEFAULTS{'PageSize'}})) {
    $Text_PDF_API_DEFAULTS{'PageSize'}=$DEFAULTS{'PageSize'};
  }
  # Pull the $pageWidth, and $pageHeight from Text::PDF::API
  if ($Text_PDF_API_DEFAULTS{PageOrientation} =~ m/^L/i) {
    ($pageHeight,$pageWidth)=
	@{$Text::PDF::API::pagesizes{$Text_PDF_API_DEFAULTS{'PageSize'}}};
  } else {
    ($pageWidth,$pageHeight)=
	@{$Text::PDF::API::pagesizes{$Text_PDF_API_DEFAULTS{'PageSize'}}};
  }

  my $self= { pdf          => Text::PDF::API->new(%Text_PDF_API_DEFAULTS),
              hPos         => undef,
              vPos         => undef,
              size         => 12,		# Default
              font         => 'Helvetica',	# Default
              PageWidth    => $pageWidth,
              PageHeight   => $pageHeight,
              Xmargin      => $MARGINX,
              Ymargin      => $MARGINY,
              BodyWidth    => $pageWidth - $MARGINX * 2,
              BodyHeight   => $pageHeight - $MARGINY * 2,
              page         => 1,
              align        => 'left',
              linespacing  => 0,
              FtrFontName  => 'Helvetica-Bold',
              FtrFontSize  => 11,
              MARGIN_DEBUG => 0
            };

  bless $self, $class;

  # Set "my" defaults from %defaults
  my @mykeys=grep(!/^pdf$/, keys %$self);
  foreach my $key (@mykeys) {
    if (defined($defaults{$key})) {
      $self->{$key}=$defaults{$key};
    }
  }

  return $self;

} # end new

# This function starts a new page
sub newpage {
  my $self = shift @_;
  my $no_page_number=shift @_;
  my $page_size = shift @_;

  # Append an endpage() if this is not the first page
  if ($self->{page} != 1) {
    # Append an endpage -- this need to be reviewed. -- LHH
    $self->{code}.="\$self->{pdf}->endpage();\n";
  }

  # Pull the $pageWidth, and $pageHeight from Text::PDF::API if $page_size
  if (defined($page_size) && defined($Text::PDF::API::pagesizes{$page_size})) {
    ($pageWidth,$pageHeight)=@{$Text::PDF::API::pagesizes{$page_size}};
    $self->{'PageWidth'}=$pageWidth;
    $self->{'PageHeight'}=$pageHeight;
    $self->{code}.="\$self->{pdf}->newpage('$page_size');\n";
  } else {
    $self->{code}.="\$self->{pdf}->newpage();\n";
  }

  # Draw the margins so I can see them -- DEBUG -- LHH
  if ($self->{MARGIN_DEBUG}) {
    $self->drawLine($MARGINX,$MARGINY,
		$self->{BodyWidth}+$MARGINX,$self->{BodyHeight}+$MARGINY);
    $self->drawLine($MARGINX,$self->{BodyHeight}+$MARGINY,
		$self->{BodyWidth}+$MARGINX,$MARGINY);
    $self->drawRect($MARGINX,$MARGINY,$self->{BodyWidth},$self->{BodyHeight});
  }

  # If this it the first page, we have to set default font and stuff
  if ($self->{page} == 1) {
#    $self->{pdf}->addCoreFonts;	# Adds all PDF core fonts (slow...)

     $self->setFont($self->{font});

#    $self->{code}.="\$self->{pdf}->newFontCore('$self->{font}', 'latin1');\n";
#    $self->{code}.="\$self->{pdf}->useFont('$self->{font}'," .
#						"$self->{size},'latin1');\n";


    # I have to *actually* set these on the module for calcTextWidth to work.
    $self->{pdf}->newpage();
    $self->{pdf}->newFontCore($self->{font},'latin1');
    $self->{pdf}->useFont($self->{font},$self->{size},'latin1');
  }

  # Handle the page numbering if this page is to be numbered
  if (! $no_page_number) {
    # Change to the footer font.
    my $OldFontName=$self->{font};
    my $OldFontSize=$self->{size};
    $self->setFont($self->{FtrFontName});
    $self->setSize($self->{FtrFontSize});
    # Left
    my $xpad=$self->{Xmargin};
    my $x=$xpad;  my $y=8;
    my $txt="Page $self->{page} of \0totalPages";
    $self->{code}.="\$self->{pdf}->showTextXY($x, $y, '$txt');\n";
    # Right
    $x=$self->{PageWidth} - $xpad;
    $txt=$PrintDate;
    $self->{code}.="\$self->{pdf}->showTextXY_R($x, $y, '$txt');\n";
    $self->{page}++;
    # Restore the font.
    $self->setFont($OldFontName);
    $self->setSize($OldFontSize);
  } else {
    $self->{page}++;
  }
  return(0);
}

sub getPageDimensions {
  my $self=shift @_;
  return($self->{PageWidth},$self->{PageHeight});
}

# Analogous to the Text::PDF::API getDefault/setDefault functions
sub getDefault {
  my $key=shift @_;
  return(Text::PDF::API->getDefault($key));
}
sub setDefault {
  my $key=shift @_;
  my $val=shift @_;
  # I think I need to sync some $self values here -- LHH
  return(Text::PDF::API->setDefault($key,$val));
}

# Finish returns the PDF document
sub Finish {
  my $self= shift @_;
  my $DEBUG_OUTPUT=shift @_;

  my $total_pages=$self->{page} - 1;
  $self->{code}=~ s/\0totalPages/$total_pages/g;
  $self->{code}=~ s/\0//g;
  $self->{code}=~ s/\r//g;

  # Append an endpage -- this need to be reviewed. -- LHH
  $self->{code}.="\$self->{pdf}->endpage();\n";

  if ($DEBUG_OUTPUT) {
    return($self->{code});
  } else {
    # Destroy the Text::PDF::API module we used while buildin $self{code}
    $self->{pdf}->end();

    # Create a new $self->{pdf} module to process $self{code}
    $self->{pdf}=Text::PDF::API->new(%Text_PDF_API_DEFAULTS);

    # Eval the code in $self->{code}
    eval $self->{code};

    # Need to make tmp file and file handle better... - LHH
    my $tmppdf="/tmp/Text.PDF.API.Report.$$.pdf";
    $self->{pdf}->saveas("$tmppdf");
    $self->{pdf}->end();
    if (open(PDFFD, "< $tmppdf")) {
      my @arr=<PDFFD>;
      close(PDFFD);
      unlink $tmppdf;
      return join('', @arr);
    } else {
      return undef;
    }
  }
} # end Finish


# Add an image file to the PDF
sub addImg {
  my ($self, $file, $x, $y) = @_;
  $self->{code}.="{\n" .
	"  my (\$key,\$width,\$height) = \$self->{pdf}->newImage('$file');\n" .
	"  \$self->{pdf}->placeImage(\$key, $x, $y, \$width, \$height);\n" .
	"}\n";
}
# Add an image file to the PDF with scaling
sub addImgScaled {
  my ($self, $file, $x, $y, $xscale, $yscale) = @_;
  $self->{code}.="{\n" .
    "  my (\$key,\$width,\$height) = \$self->{pdf}->newImage('$file');\n" .
    "  \$self->{pdf}->placeImage(\$key, $x, $y, " .
			"\$width * $xscale, \$height * $yscale);\n" .
	"}\n";
}


# Add raw text to the PDF (no text wrapping, etc.)
sub addRawText {
  my ($self, $text, $hpos, $vpos) = @_;
  $text=~s/'/\\'/g;
  $self->{code} .= "\$self->{pdf}->showTextXY($hpos, $vpos, '$text');\n";
}

# Change the active font size
sub setSize {
  my ( $self, $size )= @_;
  $self->{size}= $size;
  $self->{code}.="\$self->{pdf}->useFont('$self->{font}',$size,'latin1');\n";
  $self->{pdf}->useFont($self->{font},$self->{size},'latin1');
} # end setSize
sub getSize {
  my $self= shift @_;
  return($self->{size});
}


sub setGfxLineWidth {
  my ($self, $w) = @_;
  $self->{GfxLineWidth}=$w;
  $self->{code} .= "\$self->{pdf}->useGfxLineWidth($w);\n";
}
sub getGfxLineWidth {
  my ($self, $w) = @_;
  return($self->{GfxLineWidth});
}

# Draws a line between two points
sub drawLine {
  my ($self, $x1, $y1, $x2, $y2) = @_;
#  $self->{code} .= "\$self->{pdf}->stroke;\n" .
#                   "\$self->{pdf}->lineXY($x1, $y1, $x2, $y2);\n" .
#                   "\$self->{pdf}->closestroke;\n";
  $self->{code} .= "\$self->{pdf}->lineXY($x1, $y1, $x2, $y2);\n" .
                   "\$self->{pdf}->stroke;\n";
}
# Draw a rectangle at $x,$y of $w,$h width and height
sub drawRect {
  my ($self, $x, $y, $w, $h) = @_;
#  $self->{code} .= "\$self->{pdf}->stroke;\n" .
#                   "\$self->{pdf}->rect($x, $y, $w, $h);\n" .
#                   "\$self->{pdf}->closestroke;\n";
  $self->{code} .= "\$self->{pdf}->rect($x, $y, $w, $h);\n" .
                   "\$self->{pdf}->stroke;\n";
}

sub setAlign {
  my ( $self, $align )= @_;
  $align=lc($align);
  if ($align=~m/^left$|^right$|^center$/) {
    $self->{align}=$align;
    $self->{hPos}=undef;	# Clear addText()'s tracking of hPos
  }
}
sub getAlign {
  my $self= shift @_;
  return($self->{align});
}


# This only handle Text::PDF::API Core fonts!
sub setFont {
  my ( $self, $font )= @_;

  # If the font the user asked for is not a Text::PDF::API::COREFONTS
  # we cannot handle this request
  if (! scalar(grep(m/$font/, @Text::PDF::API::COREFONTS))) {
    return;
  }

  $self->{font}=$font;

  if (! $self->{INCLUDED_CORE_FONTS}->{$font}) {
    $self->{code}.="\$self->{pdf}->newFontCore('$self->{font}', 'latin1');\n";
    $self->{pdf}->newFontCore($self->{font}, 'latin1');
  }
  $self->{code}.="\$self->{pdf}->useFont('$self->{font}'," .
						"$self->{size},'latin1');\n";
  $self->{pdf}->useFont($self->{font},$self->{size},'latin1');
return;
} # end setFont
sub getFont {
  my $self= shift @_;
  return($self->{font});
}

sub wrapText {
  my ( $self, $text, $width )= @_;
  return $text if ($text =~ /\n/);  # We don't wrap text with carriage returns

  my $ThisTextWidth=$self->{pdf}->calcTextWidth($text);
  return $text if ( $ThisTextWidth <= $width);

  my $widSpace = $self->{pdf}->calcTextWidth(' ');

  my $currentWidth = 0;
  my $newText = "";
  foreach ( split / /, $text ) {
    my $strWidth = $self->{pdf}->calcTextWidth($_);
    if ( ( $currentWidth + $strWidth ) > $width ) {
      $currentWidth = $strWidth + $widSpace;
      $newText .= "\n$_ ";
    } else {
      $currentWidth += $strWidth + $widSpace;
      $newText .= "$_ ";
    }
  }

  return $newText;
} # end wrapText

sub setAddTextPos {
  my ($self, $hPos, $vPos) = @_;
  $self->{hPos}=$hPos;
  $self->{vPos}=$vPos;
}
sub getAddTextPos {
  my ($self) = @_;
  return($self->{hPos}, $self->{vPos});
}

sub addText {
  my ( $self, $text, $hPos, $textWidth )= @_;

  # Push the margin on for align=left (need to work on align=right) LHH
  if ( ($hPos=~/^[0-9]+([.][0-9]+)?$/) && ($self->{align}=~ /^left$/i) ) {
    $self->{hPos}=$hPos + $self->{Xmargin};
  }

  # Establish a proper $self->{hPos} is we don't have one already
  if ($self->{hPos} !~ /^[0-9]+([.][0-9]+)?$/) {
    if ($self->{align}=~ /^left$/i) {
      $self->{hPos} = $self->{Xmargin};
    } elsif ($self->{align}=~ /^right$/i) {
      $self->{hPos} = $self->{PageWidth} - $self->{Xmargin};
    } elsif ($self->{align}=~ /^center$/i) {
      $self->{hPos} = int($self->{PageWidth} / 2);
    }
  }

  # If the user did not give us a $textWidth, use the distance
  # from $hPos to the right margin as the $textWidth for align=left,
  # use the distance from $hPos back to the left margin for align=right
  if ( ($textWidth !~ /^[0-9]+$/) && ($self->{align}=~ /^left$/i) ) {
    $textWidth = $self->{BodyWidth} - $self->{hPos} + $MARGINX;
  } elsif ( ($textWidth !~ /^[0-9]+$/) && ($self->{align}=~ /^right$/i) ) {
    $textWidth = $self->{hPos} + $MARGINX;
  } elsif ( ($textWidth !~ /^[0-9]+$/) && ($self->{align}=~ /^center$/i) ) {
    my $textWidthL=$self->{BodyWidth} - $self->{hPos} + $MARGINX;
    my $textWidthR=$self->{hPos} + $MARGINX;
    $textWidth = $textWidthL;
    if ($textWidthR < $textWidth) { $textWidth = $textWidthR; }
    $textWidth = $textWidth * 2;
  }

  # If $self->{vPos} is not set calculate it (on first text add)
  if ( ($self->{vPos} == undef) || ($self->{vPos} == 0) ) {
    $self->{vPos} = $pageHeight - $MARGINY - $self->{size};
  }

  # If the text has no carrige returns we may need to wrap it for the user
  if ( $text !~ /\n/ ) {
    $text = $self->wrapText($text, $textWidth);
  }

  if ( $text !~ /\n/ ) {
    # Determine the width of this text
    my $thistextWidth = $self->{pdf}->calcTextWidth($text);

    # If align ne 'left' (the default) then we need to recalc the xPos
    # for this call to addRawText()  -- needs attention -- LHH
    my $xPos=$self->{hPos};
    if ($self->{align}=~ /^right$/i) {
      $xPos=$self->{hPos} - $thistextWidth;
    } elsif ($self->{align}=~ /^center$/i) {
      $xPos=$self->{hPos} - $thistextWidth / 2;
    }
    $self->addRawText($text,$xPos,$self->{vPos});

    $thistextWidth = -1 * $thistextWidth if ($self->{align}=~ /^right$/i);
    $thistextWidth = -1 * $thistextWidth / 2 if ($self->{align}=~ /^center$/i);
    $self->{hPos} += $thistextWidth;
  } else {
    $text=~ s/\n/\0\n/g;		# This copes w/strings of only "\n"
    my @lines= split /\n/, $text;
    foreach ( @lines ) {
      $text= $_;
      $text=~ s/\0//;
      if (length( $text )) {
        $self->addRawText($text, $self->{hPos}, $self->{vPos});
      }
      if (($self->{vPos} - $self->{size}) < $self->{Ymargin}) {
        $self->{vPos} = $pageHeight - $MARGINY - $self->{size};
        $self->newpage;
      } else {
        $self->{vPos} -= $self->{size} - $self->{linespacing};
      }
    }
  }

} # end addText

### THESE NEED FIXED - ASO 10/05/2001
#sub CenterString {  ### CENTERS STRING BETWEEN TWO POINTS
#  my $self = shift;
#  my $PointBegin = shift;
#  my $PointEnd = shift;
#  my $YPos = shift;
#  my $String = shift;
#
#  my $OldTextSize = $self->getSize;
#  my $TextSize = $OldTextSize;
#
#  my $Area = $PointEnd - $PointBegin;
#  
#  my $StringWidth;
#  while (($StringWidth = $self->GetStringWidth($String)) > $Area) {
#    $self->setSize(--$TextSize);  ### DECREASE THE FONTSIZE TO MAKE IT FIT
#  }
#
#  my $Offset = ($Area - $StringWidth) / 2;
#  $self->addRawText("$String",$PointBegin+$Offset,$YPos);
#  $self->setSize($OldTextSize);
#}
#
#sub GetStringWidth {
#  my $self = shift;
#  my $String = shift;
#  my $StringWidth = 0;
#
#  # GET PT LENGTH OF EACH CHARACTER IN STRING
#  # DONE THIS WAY TO HANDLE VARIABLE WIDTH FONT
#  while ($String =~ /(.)/g) {
#    $StringWidth+=$self->{pdf}->calcTextWidth($1);
#  }
#  return $StringWidth;
#}

#### have ported to here --- LHH  ####



# Needs to go away -- LHH
sub old_newPage {
  my ( $self, $last, $noNbr )= @_;

  my $oldFont  = $self->{font};
  my $oldSize  = $self->{size};
  my $oldAlign = $self->{align};

  $self->{vPos}= $pageHeight;

  $self->setFont( "Helvetica-Regu" );
  $self->setSize( 10 );
  if (! $noNbr) {
    $self->justify( "left"  );
    $self->addText( "Page $self->{page} of \0totalPages", 0 );
    $self->justify( "right" );
    $self->{hPos} = $pageWidth;
    $self->addText( $PrintDate );  #, $pageWidth );
  }
  $self->setFont( $oldFont  );
  $self->setSize( $oldSize  );
  $self->justify( $oldAlign );

  if( !$last ) {

    $self->{vPos}= 0;

    if (! $noNbr) { $self->{page}++; } 

    $self->{code}.=
"\$self->{ps}->ps_write( \"showpage\\n36 756 translate\\n1 1 scale\\n%%Page:$self->{page}\\n\" );\n";
  }

} # end NewPage


sub justify {

  my ( $self, $align )= @_;

  $self->{align}= $align;

  $self->{code}.= "\$self->{ps}->ps_set_justify( '$align' );\n";

  $self->{hPos}= $pageWidth / 2 if $self->{align}=~ /^center$/;
  $self->{hPos}= $pageWidth     if $self->{align}=~ /^right$/;
  $self->{hPos}= 0              if $self->{align}=~ /^left$/;

} # end justify


sub comment {
  my ($self, $txt) = @_;

  $self->{code} .= "# $txt\n";
}

1;

