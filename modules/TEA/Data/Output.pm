#!/usr/bin/env perl
# Toolkit for Evolutionary Analysis.
#
# An expandable toolkit written in the Perl programming language.
# TEA utilizes the BioPerl and EnsEMBL Perl API libraries for
# evolutionary comparative genomics analysis.
#
# Part of a PhD thesis entitled "Evolutionary Genomics of Organismal Diversity".
# 
# Created by Steve Moss
# gawbul@gmail.com
# 
# C/o Dr David Lunt and Dr Domino Joyce,
# Evolutionary Biology Group,
# The University of Hull.

package TEA::Data::Output;

# make life easier
use warnings;
use strict;

# imports
use Text::CSV_XS;
use Cwd;
use File::Spec;
use Statistics::R;

# export subroutines
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(write_Raw_To_CSV write_Unique_To_CSV merge_CSV write_to_File);

# write raw data to CSV
sub write_Raw_To_CSV {
	# setup variables
	my $organism = shift(@_);
	my $feature = shift(@_);
	my @data = @_;
	
	# sort the data ascending numerically
	@data = sort {$a <=> $b} @data;
	
	# get root directory and setup data path
	my $dir = getcwd();
	my $path = File::Spec->catfile($dir , "data", $organism);
	my $filename = File::Spec->catfile($path, $feature . "_raw.csv");
	
	# setup CSV
	my $csv = Text::CSV_XS->new ({ binary => 1, quote_space => 0, eol => $/ });
  	
  	# open file
  	open my $fh, ">", "$filename" or die "$filename: $!";
 	
 	# add the header line
 	$csv->print ($fh, [$organism . ".sizes"]);
	
	# iterate through the data array and print each line
	while (my $row = shift(@data)) {
		$csv->print ($fh, [$row]) or $csv->error_diag;
	}
	
	# close the CSV
	close $fh or die "$filename: $!";
	print "Outputted raw data to $filename\n";
}

# write raw data to CSV
sub write_Unique_To_CSV {
	# setup variables
	my $organism = shift(@_);
	my $feature = shift(@_);
	my @data = @_;
	
	# sort the data ascending numerically
	@data = sort {$a <=> $b} @data;
	
	# get root directory and setup data path
	my $dir = getcwd();
	my $path = File::Spec->catfile($dir , "data", $organism);
	my $filename = File::Spec->catfile($path, $feature . "_unique_raw.csv");
	
	# setup CSV
	my $csv = Text::CSV_XS->new ({ binary => 1, quote_space => 0, eol => $/ });
  	
  	# open file
  	open my $fh, ">", "$filename" or die "$filename: $!";
 	
 	# add the header line
 	$csv->print ($fh, [$organism . ".sizes"]);
	
	# iterate through the data array and print each line
	while (my $row = shift(@data)) {
		$csv->print ($fh, [$row]) or $csv->error_diag;
	}
	
	# close the CSV
	close $fh or die "$filename: $!";
	print "Outputted raw data to $filename\n";
}

sub write_FDist_To_CSV {
	
}

sub merge_CSV {
	# import data
	my $feature = shift(@_);
	my @organisms = @_;
	
	# get root directory and setup data path
	my $dir = getcwd();
	my $path = File::Spec->catfile($dir , "data");
	srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip -f`); # seed random number generator
	my $random = int(rand(9999999999)); # get random number
	my $out_file = File::Spec->catfile($dir , "data", $feature ."_all_$random.csv");
	
	# setup R and start clean R session
	my $R = Statistics::R->new();
	$R->startR;
	$R->send("library(gdata)");
	
	# traverse each organism
	for my $organism (@organisms) {
	  	# setup file path
		my $in_file = File::Spec->catfile($path, $organism, $feature . "_freqs.csv");
		# open CSV in read
		$R->send("$organism <- read.csv(\"$in_file\", header=TRUE)");
		$R->send("attach($organism)");
	}

	# bind columns and write to csv
	$R->send("merged <- cbindX(" . join(",", @organisms) . ")");
	$R->send("write.csv(merged, \"$out_file\")");

	# end R session
	$R->stopR;

	# tell user where data is
	print "Outputted all data to $out_file\n";		
	
	# return out file for R
	return $out_file;		
}

sub _old_merge_CSV {
	# import data
	my $feature = shift(@_);
	my @organisms = @_;
	my %csv_hash;
	my @order;
	
	# get root directory and setup data path
	my $dir = getcwd();
	my $path = File::Spec->catfile($dir , "data");
	srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip -f`); # seed random number generator
	my $random = int(rand(9999999999)); # get random number
	my $out_file = File::Spec->catfile($dir , "data", $feature ."_all_$random.csv");
	
	# traverse each organism
	for my $organism (@organisms) {
		# setup CSV
		my $csv = Text::CSV_XS->new ({ binary => 1 });
			  	
	  	# open file
		my $in_file = File::Spec->catfile($path, $organism, $feature . "_freqs.csv");
	  	open my $fh, "<", "$in_file" or die "$in_file: $!";
		
		# traverse file and push array_ref to array 
		my $rows = [];
		while (my $row = $csv->getline($fh)) {
			 push(@$rows, $row);
		}
		
		## display to ensure not flattened the rows
		#while (my $r = shift @{$rows}) {
		#	print join(",", @$r) . "\n";
		#}
		
		# push array to hash		
		$csv_hash{$organism} = $rows;	
		
		# close the CSV
		$csv->eof or $csv->error_diag;
		close $fh or die "$in_file: $!";
	}

  	# open the out file
  	open my $ofh, ">", "$out_file" or die "$out_file: $!";
	
	# get the size of the array in each hash array and sort in descending size
	foreach my $k (sort {scalar(@{$csv_hash{$b}}) <=> scalar(@{$csv_hash{$a}})} keys %csv_hash) {
		push(@order, $k);		
	}
	
	# display data in order
	for my $o (@order) {
		while (my $array = shift @{$csv_hash{$o}}) {
			print "@$array\n";
		}
	}
	
	# need to build rows from separate hashes
	###########################
	# *** MORE TO DO HERE *** #
	###########################
	
	# close output CSV
	close $ofh or die "$out_file: $!";

	# tell user where data is
	print "Outputted all data to $out_file\n";		
	
	# return out file for R
	return $out_file;
}

sub write_to_File {
	# setup variables
	my ($filename, $data) = @_;
	
	# open the file for read, truncate if exists
	open OUTFILE, ">", $filename or die "$filename: " . $!;
	# print data to file
	print OUTFILE $data;
	# close file
	close(OUTFILE);
}

1;