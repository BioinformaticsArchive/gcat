#!/usr/bin/env perl

# Genome Comparison and Analysis Toolkit
#
# An adaptable and efficient toolkit for large-scale evolutionary comparative genomics analysis.
# Written in the Perl programming language, GCAT utilizes the BioPerl, Perl EnsEMBL and R Statistics
# APIs.
#
# Part of a PhD thesis entitled "Evolutionary Genomics of Organismal Diversity".
#
# Coded by Steve Moss
# gawbul@gmail.com
#
# C/o Dr David Lunt and Dr Domino Joyce,
# Evolutionary Biology Group,
# The University of Hull.

=head1 NAME

	get_introns

=head1 SYNOPSIS

    get_introns species1 species2 species3
    
=head1 DESCRIPTION

	A program to retrieve all intron sequences from all genes, for a given number of species.

=cut

# import some modules to use
use strict;
use Time::HiRes qw(gettimeofday);
use Parallel::ForkManager; # used for parallel processing
use GCAT::Interface::Logging qw(logger); # for logging
use GCAT::DB::EnsEMBL qw(connect_To_EnsEMBL check_Species_List get_DB_Name get_Feature);
use GCAT::Data::Output qw(write_To_SeqIO);
use Cwd;
use File::Spec;

# get root directory and create data directory if doesn't exist
my $dir = getcwd();
mkdir "data" unless -d "data";

# get arguments
my $num_args = $#ARGV + 1;
my @organisms = @ARGV;

# check arguments list is sufficient
if ($num_args < 1) {
	logger("This script requires at least one input argument, for the organisms you wish to download the information for.", "Error");
	exit;
}

# set start time
my $start_time = gettimeofday;

# set autoflush for stdout
local $| = 1;

# setup fork manager
my $pm = new Parallel::ForkManager(8);

# connect to EnsEMBL and setup registry object
my $registry = &connect_To_EnsEMBL;

# check all species exist - no names have been mispelt?
unless (&check_Species_List($registry, @organisms)) {
	logger("You have incorrectly entered a species name or this species doesn't exist in the database.", "Error");
	exit;
}

# tell user what we're doing
print "Going to retrieve introns for $num_args species: @organisms...\n";

# go through all fish and retrieve exon ids and coordinates
my $count = 0;
foreach my $org_name (@organisms) {
	# start fork
	my $pid = $pm->start and next;
	
	# setup output filename
	mkdir "data/$org_name" unless -d "data/$org_name";
	my $path = File::Spec->catfile($dir, "data", "$org_name", "introns.fas");

	# get current database name
	my ($dbname, $release) = &get_DB_Name($registry, $org_name);
	
	# let user know we're starting
	print "Retrieving introns for $dbname...\n";

	# retrieve introns from gene IDs
	my @introns = &get_Feature($registry, $org_name, "Introns");
	
	# write to fasta
	my $write_count = &write_To_SeqIO($path, "Fasta", @introns);
	
	# how many have we done?
	print "\nRetrieved $write_count introns for $org_name.\n";
	
	# finish fork
	$pm->finish;
}
# wait for all processes to finish
$pm->wait_all_children;

# set end time and calculate time elapsed
my $end_time = gettimeofday;
my $elapsed = $end_time - $start_time;

# let user know we have finished
printf "Finished in %0.3f!\n", $elapsed;
