#!/usr/bin/perl -t
#
# Convert 'VTT' transcript into an Nvivo-friendly TSV form.
#
# Example: to transform a MS Teams transcript with a 2s time shift:
#
#   $ xscript2nvivo.pl 2000 < input.vtt > output.tsv
#
# Copyright (c) 2022 Andrew Bower <andrew@bower.org.uk>
#
# SPDX-License-Identifier: BSD-2-Clause

use strict;
use Math::Round;

my $state = 'IDLE';
my $quantum = 0.1;
my @format = ( 'Timespan', 'Speaker', 'Content' );
my $tshift_ms = int(shift);

my $record;
my @records;

while (<STDIN>) {
  chomp;
  if ($state eq 'IDLE') {
    if (/^WEBVTT/) {
      $state = 'VTT';
    }
  } elsif ($state eq 'VTT') {
    if (/(\d+):(\d+):(\d+)\.(\d+) --> .*/) {
      $record = {};
      my $time = int(int($4) / 1000.0 / $quantum);
      $time += int($3) * 1.0 / $quantum;
      $time += int($2) * 60.0 / $quantum;
      $time += int($1) * 3600.0 / $quantum;
      $time += $tshift_ms / 1000.0 / $quantum;
      $record->{'time'} = $time;
      $state = 'TIME';
    }
  } elsif ($state eq 'TIME') {
    if (m,<v ([^>]*)>(.*)</v>,) {
      $record->{'Speaker'} = $1;
      $record->{'Content'} = $2;
      push @records, $record;
      $state = 'VTT';
    }
  }
};

@records = sort { $a->{'time'} <=> $b->{'time'} } @records;

my $latest = -$quantum;

print join("\t", @format);
print "\n";

for my $record (@records) {
  my $t = $record->{'time'};
  if ($t <= $latest) {
    $t = $latest + 1;
  }

  my $secs = $t * $quantum;
  my $h = int($secs / 3600.0);
  $secs -= $h * 3600.0;
  my $m = int($secs / 60.0);
  $secs -= $m * 60.0;
  my $s = int($secs);
  $secs -= $s;
  my $ms = $secs * 1000;

  # Change formatting if quantum changes from 0.1
  $record->{'Timespan'} = sprintf("%02d:%02d:%02d.%.0f", $h, $m, $s, round ($ms / 1000.0 / $quantum));

  print join("\t", (map { $record->{$_} } @format));
  print "\n";

  $latest = $t;
}
