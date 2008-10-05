#!/usr/bin/perl -w

# This script requires the XML-LibXML extentions by Christian Glahn from cpan

use strict;
use Cwd;
use XML::LibXML;
use File::Copy;


#####################################################################
# Modify here the version and years:                                #

my $scriptP3Version = "1.1.4";
my $scriptP3Years = "1996,1997,1998,1999,2000,2001,2004,2006,2007,2008";

# Modify here the order of the textblocks or add new:
my @textblocksOrder = (
"copyrightLicense",
"introduction",
"citationRequest",
"contact",
"installGeneral",
"buildOsX",
"systemRequirements",
"invokingPrimer3",
"commandLineTags",
"inputOutputConventions",
"sequenceTags",
"globalTags",
"programTags",
"outputTags",
"example");
#####################################################################


my $output_folder = cwd.'/script_output/';

print"start processing\n";

# Open the input Tag file
my $tagFile = "primer3_input_tags.xml";
my $tagRoot = getXmlRoot($tagFile);
# Read all Tag in an array
my @xml_tags = $tagRoot->getElementsByTagName('tag');
# First sort the tags alphabetically tags
my @sortedTags = sort tagSort @xml_tags;
# Print a message about the Tags
my $readTagCount = $#sortedTags + 1;
print "Read in $readTagCount input Tags for processing...\n";


# Open the comad line Tag file
my $commandFile = "primer3_command_line.xml";
my $commandRoot = getXmlRoot($commandFile);
# Read all Tag in an array
my @commandTags = $commandRoot->getElementsByTagName('tag');
# Print a message about the Tags
$readTagCount = $#commandTags + 1;
print "Read in $readTagCount command line Tags for processing...\n";


# Open the TextBlocks file
my $textblocksFile = "primer3_textblocks.xml";
my $textblocksRoot = getXmlRoot($textblocksFile);
# Read all Tag in an array
my @textblocksTags = $textblocksRoot->getElementsByTagName('textBlock');
# Now read everything into two hashes
my %textHead;
my %textBody;
foreach my $idHolder (@textblocksTags) {
	my $id = get_node_content($idHolder, "id");
	$textHead{$id} = get_node_content($idHolder, "head");
	$textBody{$id} = get_node_content($idHolder, "text");
}

# Print a message about the TextBlocks
my $readtextblocksCount = $#textblocksTags + 1;
print "Read in $readtextblocksCount textblocks for processing...\n";





print "\n";

# Create the readme.txt
createReadmeTxt();

# Create the tag_definitions.xml
createTagDefinitionsXml();

# Create the readme.htm
createReadmeHtml();


print"end processing\n";





###########################################
# Opent the xml file and returns the root #
###########################################
sub getXmlRoot {
	my $file = shift;
	
	# Open the xml File
	my $parser = XML::LibXML->new();
	my $tree = $parser->parse_file($file);
	my $root = $tree->getDocumentElement;
	
	# Get the root element name
	my $rootName = $root->nodeName;
	
	# Check the root element to be sure to have the right file
	if ($rootName ne "primer3Doc") {
		print "Error: $rootName of $file is not \"primer3Doc\"\n";
		exit;
	}
	return $root;
}

##################################################
# sorts the tags alphabetically #
##################################################
sub tagSort {
	my $first = get_node_content($a, "tagName");
	my $second = get_node_content($b, "tagName");
	uc($first) cmp uc($second);
}

##################################################
# returns the html for the content of plain_page #
##################################################
sub get_node_content {
	my $root = shift;
	my $node = shift;
	
	my @xml = $root->getElementsByTagName($node);

	my $txt;
	
	if (!(defined ($xml[0]))) {
		$txt = "";
		return $txt;
	}

	$txt = $xml[0]->textContent();
	
	$txt =~ s/^\s+//;
	$txt =~ s/\s+$//;
	
	return $txt;
}

##########################################
# Writes a string int a File and returns #
#      0 for success                     #
#      or error message                  #
##########################################
sub string2file {
	my $file = shift;	# File Name
	my $string = shift; # String to save in
	my $error = 0;
	
	$string =~ s/<br \/>/<br>/g;

	if (open FILE, ">:utf8", $file) { 
		print FILE $string;
		close(FILE);
		
	} 
	else {
		$error = "Couldn't open $file for writing!\n";
	}

    return $error;
}


###############################
# creates the readme txt file #
###############################
sub createReadmeTxt {
	# Prepare the strings for the files
	my $txt_string = underlineText("primer3 release $scriptP3Version");
	$txt_string .= "\n";

# Create a Index
	$txt_string .= underlineText("Index of contents")."\n";
	my $chapterCount = 0;
	foreach my $textblock_holder (@textblocksOrder) {
		if ($textHead{$textblock_holder} ne ""){
			$chapterCount++;
			$txt_string .= "$chapterCount. $textHead{$textblock_holder}\n";
		}
	}
	$txt_string .= "\n\n";

	$chapterCount = 0;
	foreach my $textblock_holder (@textblocksOrder) {
		if ($textHead{$textblock_holder} ne ""){
		$chapterCount++;
			$txt_string .= underlineText("$chapterCount. $textHead{$textblock_holder}");
			$txt_string .= "$textBody{$textblock_holder}\n\n\n";
		}
		# Print out the command line tags at the right spot
		if ($textblock_holder eq "commandLineTags") {
			$txt_string =~ s/\n$//;
			foreach my $tag_holder (@commandTags) {
				# Get all the XML data of one tag
				my $tagName = get_node_content($tag_holder, "tagName");
				my $description = get_node_content($tag_holder, "description");
				
				# Assemble the txt file
				$txt_string .= $tagName."\n";
				$txt_string .= "   $description\n\n";
			}
			$txt_string .= "\n";
		}
		if ($textblock_holder eq "sequenceTags") {
			$txt_string =~ s/\n$//;
			$txt_string .= printTags("SEQUENCE_");
		}
		if ($textblock_holder eq "globalTags") {
			$txt_string =~ s/\n$//;
			$txt_string .= printTags("PRIMER_");
		}
		if ($textblock_holder eq "programTags") {
			$txt_string =~ s/\n$//;
			$txt_string .= printTags("P3_");
		}
	}

	# Write the files to the disk
	my $output_file = $output_folder. "readme.txt";
	string2file($output_file, $txt_string);

	return 0;
}

######################################
# prints all tags of a certain group #
######################################
sub printTags {
	my $text = shift;
	my $output;
	my $tagCount = 0;	
	# Now print out all tags
	foreach my $tag_holder (@sortedTags) {
		# Get all the XML data of one tag
		my $tagName = get_node_content($tag_holder, "tagName");
		my $dataType = get_node_content($tag_holder, "dataType");
		my $default = get_node_content($tag_holder, "default");
		my $description = get_node_content($tag_holder, "description");
		
		if ($tagName =~ /^$text/) {
			$tagCount++;
			
			# Assemble the txt file
			$output .= $tagName." (".$dataType."; default ".$default.")\n\n";
			$output .= "$description\n\n\n";
		}
		
	}

	print "Printed $tagCount $text - Tags in readme.txt\n";
	
	return $output;
}


##############################
# underlines the text with - #
##############################
sub underlineText {
	my $text = shift;
	my $output = "$text\n";
	$text =~ s/./-/g;
	$output .= "$text\n";
	
	return $output;
}


########################################
# creates the tag_definitions.xml file #
########################################
sub createTagDefinitionsXml {
	# Prepare the strings for the files
	my $xml_string = qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<tagList version="1.0">
};
	my $tagCount = 0;
	
	# Now print out all tags
	foreach my $tag_holder (@sortedTags) {
		$tagCount++;
		
		# Get all the XML data of one tag
		my $tagName = get_node_content($tag_holder, "tagName");
		my $dataType = get_node_content($tag_holder, "dataType");
		my $default = get_node_content($tag_holder, "default");
		my $description = get_node_content($tag_holder, "description");
	
		# Assemble the XML file
		$xml_string .= "<tag>\n\t<tagName>".$tagName."</tagName>\n\t<dataType>";
		$xml_string .= $dataType."</dataType>\n\t<default>".$default;
		$xml_string .= "</default>\n\t<description>\n<![CDATA[";
		$xml_string .= $description."]]>\n\t</description>\n</tag>\n";
		
	}
	
	# Finish the strings for the files
	$xml_string .= "</tagList>\n";
	
	# Write the files to the disk
	my $output_file = $output_folder. "tag_definitions.xml";
	string2file($output_file, $xml_string);

	print "Printed $tagCount Tags in tag_definitions.xml\n";

	return 0;
}

###############################
# creates the readme txt file #
###############################
sub createReadmeHtml {
	# Prepare the strings for the files
	my $html_string = html_get_header();
	my $tagCount = 0;
	
	# Lets print the overview table for the HTML file
	foreach my $tag_holder (@sortedTags) {
		# Get all the XML data of one tag
		my $tagName = get_node_content($tag_holder, "tagName");
	
	
		# Assemble the html file
		$html_string .= "<a href=\"#$tagName\" style=\"font-size:0.8em\">".$tagName."</a><br>\n\n";
	
		
	}
	
	# Now print out all tags
	foreach my $tag_holder (@sortedTags) {
		$tagCount++;
		
		# Get all the XML data of one tag
		my $tagName = get_node_content($tag_holder, "tagName");
		my $dataType = get_node_content($tag_holder, "dataType");
		my $default = get_node_content($tag_holder, "default");
		my $description = get_node_content($tag_holder, "description");
	
	
		# Assemble the html file
		$html_string .= "<h3><a name=\"$tagName\">".$tagName."</a></h3>\n\n<p>(";
		$html_string .= $dataType."; default ".$default.")<br><br>\n\n";
		$html_string .= "$description</p>\n\n\n";
	
		
	}
	
	# Finish the strings for the files
	$html_string .= html_get_footer();
	
	print "\nPrinted out $tagCount Tags!\n\n";
	
	# Write the files to the disk
	my $output_file = $output_folder. "readme.htm";
	string2file($output_file, $html_string);


	print "Printed $tagCount Tags in readme.htm\n";

	return 0;
}


###################################
# returns the html for the header #
# opens <html> <body> <div page>  #
###################################
sub html_get_header {
	my $html = qq{<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN"
        "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
  <meta content="text/html; charset=ISO-8859-1" http-equiv="content-type">
  <title>Primer3 - Readme</title>
  <style type="text/css">
  body {
  background-color:white;
  color:black;
  font-size:100.01%;
  margin:0;
  min-width:41em;
  padding:5px;
  text-align:left;
  }

  div#page {
  background:#FFFFFF;
  margin:25px;
  padding:0;
  text-align:left;
  width:900px;
  }
  </style>
</head>
<body>
<div id="page">
};

	return $html;
}


###################################
# returns the html for the footer #
# closes <div page> <body> <html> #
###################################
sub html_get_footer {
	my $html =
	qq{</div>
</body>
</html>
};
	
	return $html;
}

