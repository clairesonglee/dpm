#!/usr/bin/env perl
#
#  (C) 2015 by Argonne National Laboratory.
#      See COPYRIGHT in top-level directory.
#

# Set via configure
my $PREFIX="/usr/local";

use warnings;
use lib "/usr/local/lib";
use TeX::Encode;
use Encode;
use File::Temp qw/ tempdir /;
use File::Basename;
use Cwd;
use Getopt::Long;
use English;
use Number::Bytes::Human qw(format_bytes);
use POSIX qw(strftime);

#
# system commands used
#
my $darshan_parser = "$PREFIX/bin/darshan-parser";
my $pdflatex       = "pdflatex";
my $epstopdf       = "epstopdf";
my $cp             = "cp";
my $mv             = "mv";
my $gnuplot        = "gnuplot";

my $orig_dir = getcwd;
my $output_file = "summary.pdf";
my $verbose_flag = 0;
my $summary_flag = 0;
my $input_file = "";
my %posix_access_hash = ();
my %mpiio_access_hash = ();
my @access_size = ();
my %hash_files = ();
my $partial_flag = 0;

# data structures for calculating performance
my %hash_unique_file_time = ();
my $shared_file_time = 0;
my $total_job_bytes = 0;

process_args();

check_prereqs();

my $tmp_dir = tempdir( CLEANUP => !$verbose_flag );
if ($verbose_flag)
{
    print "verbose: $tmp_dir\n";
}

open(PARSE_OUT, "$darshan_parser --base --perf $input_file |") || die("Can't execute \"$darshan_parser $input_file\": $!\n");

open(FA_READ, ">$tmp_dir/file-access-read.dat") || die("error opening output file: $!\n");
open(FA_WRITE, ">$tmp_dir/file-access-write.dat") || die("error opening output file: $!\n");
open(FA_READ_SH, ">$tmp_dir/file-access-read-sh.dat") || die("error opening output file: $!\n");
open(FA_WRITE_SH, ">$tmp_dir/file-access-write-sh.dat") || die("error opening output file: $!\n");

my $last_read_start = 0;
my $last_write_start = 0;

my $cumul_read_indep = 0;
my $cumul_read_bytes_indep = 0;

my $cumul_write_indep = 0;
my $cumul_write_bytes_indep = 0;

my $cumul_read_shared = 0;
my $cumul_read_bytes_shared = 0;

my $cumul_write_shared = 0;
my $cumul_write_bytes_shared = 0;

my $cumul_meta_shared = 0;
my $cumul_meta_indep = 0;

my $perf_layer = "";
my $perf_est = 0.0;
my $perf_mbytes = 0;
my $current_module = "";
my $stdio_perf_est = 0.0;
my $stdio_perf_mbytes = 0;

my $first_data_line = 1;
my %file_record_hash = ();
my %fs_data = ();

while($line = <PARSE_OUT>)
{
    chomp($line);

    if ($line =~ /^\s*$/)
    {
        # ignore blank lines
    }
    elsif ($line =~ /^#/)
    {
        if ($line =~ /^# exe: /)
        {
            $f_save = "";
            ($junk, $cmdline) = split(':', $line, 2);

            # add escape characters if needed for special characters in
            # command line
            if ($cmdline =~ /<unknown args>/)
            {
                # fortran "<unknown args> seems to throw things off,
                # so we don't encode that if it's present
                $f_save = substr($cmdline, -14);
                $cmdline = substr($cmdline, 0, -14); 
            }
            $cmdline = encode('latex', $cmdline) . $f_save;
        }
        elsif ($line =~ /^# nprocs: /)
        {
            ($junk, $nprocs) = split(':', $line, 2);
        }
        elsif ($line =~ /^# run time: /)
        {
            ($junk, $runtime) = split(':', $line, 2);
        }
        elsif ($line =~ /^# start_time: /)
        {
            ($junk, $starttime) = split(':', $line, 2);
        }
        elsif ($line =~ /^# uid: /)
        {        
            ($junk, $uid) = split(':', $line, 2);
        }
        elsif ($line =~ /^# jobid: /)
        {
            ($junk, $jobid) = split(':', $line, 2);
        }
        elsif ($line =~ /^# darshan log version: /)
        {
            ($junk, $version) = split(':', $line, 2);
            $version =~ s/^\s+//;
        }
        elsif ($line =~ /^# agg_perf_by_slowest: /)
        {
            if($current_module eq "STDIO")
            {
                ($junk, $stdio_perf_est) = split(':', $line, 2);
                $stdio_perf_est = sprintf("%.2f", $stdio_perf_est);
            }
            elsif($current_module eq "POSIX")
            {
                ($junk, $perf_est) = split(':', $line, 2);
                $perf_est = sprintf("%.2f", $perf_est);
                $perf_layer = "POSIX";
            }
            elsif($current_module eq "MPI-IO")
            {
                ($junk, $perf_est) = split(':', $line, 2);
                $perf_est = sprintf("%.2f", $perf_est);
                $perf_layer = "MPI-IO";
            }
        }
        elsif ($line =~ /^# total_bytes: /)
        {
            if($current_module eq "STDIO")
            {
                ($junk, $stdio_perf_mbytes) = split(':', $line, 2);
                $stdio_perf_mbytes = $stdio_perf_mbytes / 1024 / 1024;
                $stdio_perf_mbytes = sprintf("%.1f", $stdio_perf_mbytes);
            }
            elsif($perf_mbytes == 0)
            {
                ($junk, $perf_mbytes) = split(':', $line, 2);
                $perf_mbytes = $perf_mbytes / 1024 / 1024;
                $perf_mbytes = sprintf("%.1f", $perf_mbytes);
            }
        }
        elsif ($line =~ /^# \*WARNING\*: .* contains incomplete data!/)
        {
            $partial_flag = 1;
        }
        elsif ($line =~ /^# (.+) module data/)
        {
            $current_module = $1;
        }
    }
    else
    {
        # parse line
        @fields = split(/[\t ]+/, $line);

        # encode the file system name to protect against special characters
        $fields[6] = encode('latex', $fields[6]);

        # is this our first piece of data?
        if($first_data_line)
        {
            $first_data_line = 0;
        }

        # is this a new file record?
        if (!defined $file_record_hash{$fields[2]})
        {
            $file_record_hash{$fields[2]} = ();
            $file_record_hash{$fields[2]}{FILE_NAME} = $fields[5];
            $file_record_hash{$fields[2]}{RANK} = $fields[1];
        }

        $file_record_hash{$fields[2]}{$fields[3]} = $fields[4];
        $summary{$fields[3]} += $fields[4];

        # accumulate independent and shared data as well as fs data
        if ($fields[3] eq "POSIX_F_READ_TIME" || $fields[3] eq "STDIO_F_READ_TIME")
        {
            if ($fields[1] == -1)
            {
                $cumul_read_shared += $fields[4];
            }
            else
            {
                $cumul_read_indep += $fields[4];
            }
        }
        elsif ($fields[3] eq "POSIX_F_WRITE_TIME" || $fields[3] eq "STDIO_F_WRITE_TIME")
        {
            if ($fields[1] == -1)
            {
                $cumul_write_shared += $fields[4];
            }
            else
            {
                $cumul_write_indep += $fields[4];
            }
        }
        elsif ($fields[3] eq "POSIX_F_META_TIME" || $fields[3] eq "STDIO_F_META_TIME")
        {
            if ($fields[1] == -1)
            {
                $cumul_meta_shared += $fields[4];
            }
            else
            {
                $cumul_meta_indep += $fields[4];
            }
        }
        elsif ($fields[3] eq "POSIX_BYTES_READ" || $fields[3] eq "STDIO_BYTES_READ")
        {
            if ($fields[1] == -1)
            {
                $cumul_read_bytes_shared += $fields[4];
            }
            else
            {
                $cumul_read_bytes_indep += $fields[4];
            }
            if (not defined $fs_data{$fields[6]})
            {
                $fs_data{$fields[6]} = [0,0];
            }
            $fs_data{$fields[6]}->[0] += $fields[4];
        }
        elsif ($fields[3] eq "POSIX_BYTES_WRITTEN" || $fields[3] eq "STDIO_BYTES_WRITTEN")
        {
            if ($fields[1] == -1)
            {
                $cumul_write_bytes_shared += $fields[4];
            }
            else
            {
                $cumul_write_bytes_indep += $fields[4];
            }
            if (not defined $fs_data{$fields[6]})
            {
                $fs_data{$fields[6]} = [0,0];
            }
            $fs_data{$fields[6]}->[1] += $fields[4];
        }

        # record start and end of reads and writes
        elsif ($fields[3] eq "POSIX_F_READ_START_TIMESTAMP" ||
            $fields[3] eq "STDIO_F_READ_START_TIMESTAMP")
        {
            # store until we find the end
            $last_read_start = $fields[4];
        }
        elsif (($fields[3] eq "POSIX_F_READ_END_TIMESTAMP" || $fields[3] eq "STDIO_F_READ_END_TIMESTAMP") && $fields[4] != 0)
        {
            # assume we got the read start already 
            my $xdelta = $fields[4] - $last_read_start;
            if($fields[1] == -1)
            {
                print FA_READ_SH "$last_read_start\t0\t$xdelta\t0\n";
            }
            else
            {
                print FA_READ "$last_read_start\t$fields[1]\t$xdelta\t0\n";
            }
        }
        elsif ($fields[3] eq "POSIX_F_WRITE_START_TIMESTAMP" ||
            $fields[3] eq "STDIO_F_WRITE_START_TIMESTAMP")
        {
            # store until we find the end
            $last_write_start = $fields[4];
        }
        elsif (($fields[3] eq "POSIX_F_WRITE_END_TIMESTAMP" || $fields[3] eq "STDIO_F_WRITE_END_TIMESTAMP") && $fields[4] != 0)
        {
            # assume we got the write start already 
            my $xdelta = $fields[4] - $last_write_start;
            if($fields[1] == -1)
            {
                print FA_WRITE_SH "$last_write_start\t0\t$xdelta\t0\n";
            }
            else
            {
                print FA_WRITE "$last_write_start\t$fields[1]\t$xdelta\t0\n";
            }
        }

        # record common access counter info
        elsif ($fields[3] =~ /^POSIX_ACCESS(.)_ACCESS/)
        {
            $access_size[$1] = $fields[4];
        }
        elsif ($fields[3] =~ /^MPIIO_ACCESS(.)_ACCESS/)
        {
            $access_size[$1] = $fields[4];
        }
        elsif ($fields[3] =~ /^POSIX_ACCESS(.)_COUNT/)
        {
            my $tmp_access_size = $access_size[$1];
            if(defined $posix_access_hash{$tmp_access_size})
            {
                $posix_access_hash{$tmp_access_size} += $fields[4];
            }
            else
            {
                $posix_access_hash{$tmp_access_size} = $fields[4];
            }
        }
        elsif ($fields[3] =~ /^MPIIO_ACCESS(.)_COUNT/)
        {
            my $tmp_access_size = $access_size[$1];
            if(defined $mpiio_access_hash{$tmp_access_size})
            {
                $mpiio_access_hash{$tmp_access_size} += $fields[4];
            }
            else
            {
                $mpiio_access_hash{$tmp_access_size} = $fields[4];
            }
        }
    }
}
close(PARSE_OUT) || die "darshan-parser failure: $! $?";

# Fudge one point at the end to make xrange match in read and write plots.
# For some reason I can't get the xrange command to work.  -Phil
print FA_READ "$runtime\t-1\t0\t0\n";
print FA_WRITE "$runtime\t-1\t0\t0\n";
print FA_READ_SH "$runtime\t0\t0\t0\n";
print FA_WRITE_SH "$runtime\t0\t0\t0\n";
close(FA_READ);
close(FA_READ_SH);
close(FA_WRITE);
close(FA_WRITE_SH);

#
# Exit out if there are no actual file accesses
#
if ($first_data_line)
{
    $strtm = strftime("%a %b %e %H:%M:%S %Y", localtime($starttime));

    print "This darshan log has no file records. No summary was produced.\n";
    print "    jobid: $jobid\n";
    print "      uid: $uid\n";
    print "starttime: $strtm ($starttime )\n";
    print "  runtime: $runtime (seconds)\n";
    print "   nprocs: $nprocs\n";
    print "  version: $version\n";
    exit(1);
}

foreach $key (keys %file_record_hash)
{
    process_file_record($key, \%{$file_record_hash{$key}});
}

# copy template files to tmp tmp_dir
system "$cp $PREFIX/share/*.gplt $tmp_dir/";
system "$cp $PREFIX/share/*.tex $tmp_dir/";


# summary of time spent in POSIX & MPI-IO functions
open(TIME_SUMMARY, ">$tmp_dir/time-summary.dat") || die("error opening output file:$!\n");
print TIME_SUMMARY "# <type>, <app time>, <read>, <write>, <meta>\n";
if (defined $summary{POSIX_OPENS})
{
    print TIME_SUMMARY "POSIX, ", ((($runtime * $nprocs - $summary{POSIX_F_READ_TIME} -
        $summary{POSIX_F_WRITE_TIME} -
        $summary{POSIX_F_META_TIME})/($runtime * $nprocs)) * 100);
    print TIME_SUMMARY ", ", (($summary{POSIX_F_READ_TIME}/($runtime * $nprocs))*100);
    print TIME_SUMMARY ", ", (($summary{POSIX_F_WRITE_TIME}/($runtime * $nprocs))*100);
    print TIME_SUMMARY ", ", (($summary{POSIX_F_META_TIME}/($runtime * $nprocs))*100), "\n";
}
if (defined $summary{MPIIO_INDEP_OPENS})
{
    print TIME_SUMMARY "MPI-IO, ", ((($runtime * $nprocs - $summary{MPIIO_F_READ_TIME} -
        $summary{MPIIO_F_WRITE_TIME} -
        $summary{MPIIO_F_META_TIME})/($runtime * $nprocs)) * 100);
    print TIME_SUMMARY ", ", (($summary{MPIIO_F_READ_TIME}/($runtime * $nprocs))*100);
    print TIME_SUMMARY ", ", (($summary{MPIIO_F_WRITE_TIME}/($runtime * $nprocs))*100);
    print TIME_SUMMARY ", ", (($summary{MPIIO_F_META_TIME}/($runtime * $nprocs))*100), "\n";
}
if (defined $summary{STDIO_OPENS})
{
    print TIME_SUMMARY "STDIO, ", ((($runtime * $nprocs - $summary{STDIO_F_READ_TIME} -
        $summary{STDIO_F_WRITE_TIME} -
        $summary{STDIO_F_META_TIME})/($runtime * $nprocs)) * 100);
    print TIME_SUMMARY ", ", (($summary{STDIO_F_READ_TIME}/($runtime * $nprocs))*100);
    print TIME_SUMMARY ", ", (($summary{STDIO_F_WRITE_TIME}/($runtime * $nprocs))*100);
    print TIME_SUMMARY ", ", (($summary{STDIO_F_META_TIME}/($runtime * $nprocs))*100), "\n";
}
close TIME_SUMMARY;

# counts of operations
open(PSX_OP_COUNTS, ">$tmp_dir/posix-op-counts.dat") || die("error opening output file: $!\n");
print PSX_OP_COUNTS "# <operation>, <POSIX count>\n";
if (defined $summary{POSIX_OPENS})
{
    print PSX_OP_COUNTS
        "Read, ", $summary{POSIX_READS}, "\n",
        "Write, ", $summary{POSIX_WRITES}, "\n",
        "Open, ", $summary{POSIX_OPENS}, "\n",
        "Stat, ", $summary{POSIX_STATS}, "\n",
        "Seek, ", $summary{POSIX_SEEKS}, "\n",
        "Mmap, ", $summary{POSIX_MMAPS}, "\n",
        "Fsync, ", $summary{POSIX_FSYNCS} + $summary{POSIX_FDSYNCS}, "\n";
}
else
{
    print PSX_OP_COUNTS
        "Read, 0\n",
        "Write, 0\n",
        "Open, 0\n",
        "Stat, 0\n",
        "Seek, 0\n",
        "Mmap, 0\n",
        "Fsync, 0\n";
}
close PSX_OP_COUNTS;

if (defined $summary{MPIIO_INDEP_OPENS})
{
    # TODO: do we want to look at MPI split or non-blocking i/o here? 
    open(MPI_OP_COUNTS, ">$tmp_dir/mpiio-op-counts.dat") || die("error opening output file: $!\n");
    print MPI_OP_COUNTS "# <operation>, <MPI Ind. count>, <MPI Coll. count>\n";
    print MPI_OP_COUNTS
        "Read, ", $summary{MPIIO_INDEP_READS}, ", ", $summary{MPIIO_COLL_READS}, "\n",
        "Write, ", $summary{MPIIO_INDEP_WRITES}, ", ", $summary{MPIIO_COLL_WRITES}, "\n",
        "Open, ", $summary{MPIIO_INDEP_OPENS},", ", $summary{MPIIO_COLL_OPENS}, "\n",
        "Stat, ", "0, 0\n",
        "Seek, ", "0, 0\n",
        "Mmap, ", "0, 0\n",
        "Fsync, ", "0, ", $summary{MPIIO_SYNCS}, "\n";
    close MPI_OP_COUNTS;
}

if (defined $summary{STDIO_OPENS})
{
    open(STDIO_OP_COUNTS, ">$tmp_dir/stdio-op-counts.dat") || die("error opening output file: $!\n");
    print STDIO_OP_COUNTS "# <operation>, <STDIO count>\n";
    print STDIO_OP_COUNTS
        "Read, ", $summary{STDIO_READS}, "\n",
        "Write, ", $summary{STDIO_WRITES}, "\n",
        "Open, ", $summary{STDIO_OPENS}, "\n",
        "Stat, 0\n",
        "Seek, ", $summary{STDIO_SEEKS}, "\n",
        "Mmap, 0\n",
        "Fsync, ", $summary{STDIO_FLUSHES}, "\n";
    close STDIO_OP_COUNTS;
}

# histograms of reads and writes (for POSIX and MPI-IO modules)
open (IO_HIST, ">$tmp_dir/posix-access-hist.dat") || die("error opening output file: $!\n");
print IO_HIST "# <size_range>, <POSIX_reads>, <POSIX_writes>\n";
if (defined $summary{POSIX_OPENS})
{
    print IO_HIST "0-100, ",
                  $summary{POSIX_SIZE_READ_0_100}, ", ",
                  $summary{POSIX_SIZE_WRITE_0_100}, "\n";
    print IO_HIST "101-1K, ",
                  $summary{POSIX_SIZE_READ_100_1K}, ", ",
                  $summary{POSIX_SIZE_WRITE_100_1K}, "\n";
    print IO_HIST "1K-10K, ",
                  $summary{POSIX_SIZE_READ_1K_10K}, ", ",
                  $summary{POSIX_SIZE_WRITE_1K_10K}, "\n";
    print IO_HIST "10K-100K, ",
                  $summary{POSIX_SIZE_READ_10K_100K}, ", ",
                  $summary{POSIX_SIZE_WRITE_10K_100K}, "\n";
    print IO_HIST "100K-1M, ",
                  $summary{POSIX_SIZE_READ_100K_1M}, ", ",
                  $summary{POSIX_SIZE_WRITE_100K_1M}, "\n";
    print IO_HIST "1M-4M, ",
                  $summary{POSIX_SIZE_READ_1M_4M}, ", ",
                  $summary{POSIX_SIZE_WRITE_1M_4M}, "\n";
    print IO_HIST "4M-10M, ",
                  $summary{POSIX_SIZE_READ_4M_10M}, ", ",
                  $summary{POSIX_SIZE_WRITE_4M_10M}, "\n";
    print IO_HIST "10M-100M, ",
                  $summary{POSIX_SIZE_READ_10M_100M}, ", ",
                  $summary{POSIX_SIZE_WRITE_10M_100M}, "\n";
    print IO_HIST "100M-1G, ",
                  $summary{POSIX_SIZE_READ_100M_1G}, ", ",
                  $summary{POSIX_SIZE_WRITE_100M_1G}, "\n";
    print IO_HIST "1G+, ",
                  $summary{POSIX_SIZE_READ_1G_PLUS}, ", ",
                  $summary{POSIX_SIZE_WRITE_1G_PLUS}, "\n";
}
else
{
    print IO_HIST "0-100, 0, 0\n";
    print IO_HIST "101-1K, 0, 0\n";
    print IO_HIST "1K-10K, 0, 0\n";
    print IO_HIST "10K-100K, 0, 0\n";
    print IO_HIST "100K-1M, 0, 0\n";
    print IO_HIST "1M-4M, 0, 0\n";
    print IO_HIST "4M-10M, 0, 0\n";
    print IO_HIST "10M-100M, 0, 0\n";
    print IO_HIST "100M-1G, 0, 0\n";
    print IO_HIST "1G+, 0, 0\n";
}
close IO_HIST;

if (defined $summary{MPIIO_INDEP_OPENS})
{
    open (IO_HIST, ">$tmp_dir/mpiio-access-hist.dat") || die("error opening output file: $!\n");
    print IO_HIST "# <size_range>, <MPIIO_reads>, <MPIIO_writes>\n";
    print IO_HIST "0-100, ",
                  $summary{MPIIO_SIZE_READ_AGG_0_100}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_0_100}, "\n";
    print IO_HIST "101-1K, ",
                  $summary{MPIIO_SIZE_READ_AGG_100_1K}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_100_1K}, "\n";
    print IO_HIST "1K-10K, ",
                  $summary{MPIIO_SIZE_READ_AGG_1K_10K}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_1K_10K}, "\n";
    print IO_HIST "10K-100K, ",
                  $summary{MPIIO_SIZE_READ_AGG_10K_100K}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_10K_100K}, "\n";
    print IO_HIST "100K-1M, ",
                  $summary{MPIIO_SIZE_READ_AGG_100K_1M}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_100K_1M}, "\n";
    print IO_HIST "1M-4M, ",
                  $summary{MPIIO_SIZE_READ_AGG_1M_4M}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_1M_4M}, "\n";
    print IO_HIST "4M-10M, ",
                  $summary{MPIIO_SIZE_READ_AGG_4M_10M}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_4M_10M}, "\n";
    print IO_HIST "10M-100M, ",
                  $summary{MPIIO_SIZE_READ_AGG_10M_100M}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_10M_100M}, "\n";
    print IO_HIST "100M-1G, ",
                  $summary{MPIIO_SIZE_READ_AGG_100M_1G}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_100M_1G}, "\n";
    print IO_HIST "1G+, ",
                  $summary{MPIIO_SIZE_READ_AGG_1G_PLUS}, ", ",
                  $summary{MPIIO_SIZE_WRITE_AGG_1G_PLUS}, "\n";
    close IO_HIST;
}

    # sequential and consecutive access patterns
open (PATTERN, ">$tmp_dir/pattern.dat") || die("error opening output file: $!\n");
print PATTERN "# op total sequential consecutive\n";
if (defined $summary{POSIX_OPENS})
{
    print PATTERN "Read, ", $summary{POSIX_READS}, ", ",
        $summary{POSIX_SEQ_READS}, ", ", $summary{POSIX_CONSEC_READS}, "\n";
    print PATTERN "Write, ", $summary{POSIX_WRITES}, ", ",
        $summary{POSIX_SEQ_WRITES}, ", ", $summary{POSIX_CONSEC_WRITES}, "\n";
}
else
{
    print PATTERN "Read, 0, 0, 0\n";
    print PATTERN "Write, 0, 0, 0\n";
}
close PATTERN;

# table of common access sizes
open(ACCESS_TABLE, ">$tmp_dir/access-table.tex") || die("error opening output file:$!\n");
print ACCESS_TABLE "
\\begin{threeparttable}
\\begin{tabular}{r|r|r}
\\multicolumn{3}{c}{ } \\\\
\\multicolumn{3}{c}{Most Common Access Sizes} \\\\
\\multicolumn{3}{c}{(POSIX or MPI-IO)} \\\\
\\hline
\& access size \& count \\\\
\\hline
\\hline
";

# sort POSIX & MPI-IO access sizes (descending)
my $i = 0;
my $tmp_access_count = 0;
foreach $value (keys %posix_access_hash) {
    if ($posix_access_hash{$value} > 0) {
        $tmp_access_count++;
        if ($tmp_access_count == 4) {
            last;
        }
    }
}
if ($tmp_access_count > 0)
{
    foreach $value (sort {$posix_access_hash{$b} <=> $posix_access_hash{$a} } keys %posix_access_hash)
    {
        if ($i == 4) {
            last;
        }
        if ($posix_access_hash{$value} == 0) {
            last;
        }

        if ($i == 0) {
            print ACCESS_TABLE "
            \\multirow{$tmp_access_count}{*}{POSIX} \& $value \& $posix_access_hash{$value} \\\\\n
            ";
        }
        else {
            print ACCESS_TABLE "
            \& $value \& $posix_access_hash{$value} \\\\\n
            ";
        }
        $i++;
    }
}

$i = 0;
$tmp_access_count = 0;
foreach $value (keys %mpiio_access_hash) {
    if ($mpiio_access_hash{$value} > 0) {
        $tmp_access_count++;
        if ($tmp_access_count == 4) {
            last;
        }
    }
}
if ($tmp_access_count > 0)
{
    foreach $value (sort {$mpiio_access_hash{$b} <=> $mpiio_access_hash{$a} } keys %mpiio_access_hash)
    {
        if ($i == 4) {
            last;
        }
        if ($mpiio_access_hash{$value} == 0) {
            last;
        }

        if ($i == 0) {
            print ACCESS_TABLE "
            \\hline
            \\multirow{$tmp_access_count}{*}{MPI-IO \\textbf{\\ddag}} \& $value \& $mpiio_access_hash{$value} \\\\\n
            ";
        }
        else {
            print ACCESS_TABLE "
            \& $value \& $mpiio_access_hash{$value} \\\\\n
            ";
        }
        $i++;
    }
}

print ACCESS_TABLE "
\\hline
\\end{tabular}
";
if ($tmp_access_count > 0)
{
    print ACCESS_TABLE "
    \\begin{tablenotes}
    \\item[\\normalsize \\textbf{\\ddag}] \\scriptsize NOTE: MPI-IO accesses are given in terms of aggregate datatype size.
    \\end{tablenotes}
    ";
}
print ACCESS_TABLE "
\\end{threeparttable}
";
close ACCESS_TABLE;

# file count table
open(FILE_CNT_TABLE, ">$tmp_dir/file-count-table.tex") || die("error opening output file:$!\n");
print FILE_CNT_TABLE "
\\begin{tabular}{r|r|r|r}
\\multicolumn{4}{c}{ } \\\\
\\multicolumn{4}{c}{File Count Summary} \\\\
\\multicolumn{4}{c}{(estimated by POSIX I/O access offsets)} \\\\
\\hline
type \& number of files \& avg. size \& max size \\\\
\\hline
\\hline
";

my $counter;
my $sum;
my $max;
my $key;
my $avg;

$counter = 0;
$sum = 0;
$max = 0;
foreach $key (keys %hash_files) {
    $counter++;
    if($hash_files{$key}{'min_open_size'} >
        $hash_files{$key}{'max_size'})
    {
        $sum += $hash_files{$key}{'min_open_size'};
        if($hash_files{$key}{'min_open_size'} > $max)
        {
            $max = $hash_files{$key}{'min_open_size'};
        }
    }
    else
    {
        $sum += $hash_files{$key}{'max_size'};
        if($hash_files{$key}{'max_size'} > $max)
        {
            $max = $hash_files{$key}{'max_size'};
        }
    }
}
if($counter > 0) { $avg = $sum / $counter; }
else { $avg = 0; }
$avg = format_bytes($avg);
$max = format_bytes($max);
print FILE_CNT_TABLE "total opened \& $counter \& $avg \& $max \\\\\n";

$counter = 0;
$sum = 0;
$max = 0;
foreach $key (keys %hash_files) {
    if($hash_files{$key}{'was_read'} && !($hash_files{$key}{'was_written'}))
    {
        $counter++;
        if($hash_files{$key}{'min_open_size'} >
            $hash_files{$key}{'max_size'})
        {
            $sum += $hash_files{$key}{'min_open_size'};
            if($hash_files{$key}{'min_open_size'} > $max)
            {
                $max = $hash_files{$key}{'min_open_size'};
            }
        }
        else
        {
            $sum += $hash_files{$key}{'max_size'};
            if($hash_files{$key}{'max_size'} > $max)
            {
                $max = $hash_files{$key}{'max_size'};
            }
        }
    }
}
if($counter > 0) { $avg = $sum / $counter; }
else { $avg = 0; }
$avg = format_bytes($avg);
$max = format_bytes($max);
print FILE_CNT_TABLE "read-only files \& $counter \& $avg \& $max \\\\\n";

$counter = 0;
$sum = 0;
$max = 0;
foreach $key (keys %hash_files) {
    if(!($hash_files{$key}{'was_read'}) && $hash_files{$key}{'was_written'})
    {
        $counter++;
        if($hash_files{$key}{'min_open_size'} >
            $hash_files{$key}{'max_size'})
        {
            $sum += $hash_files{$key}{'min_open_size'};
            if($hash_files{$key}{'min_open_size'} > $max)
            {
                $max = $hash_files{$key}{'min_open_size'};
            }
        }
        else
        {
            $sum += $hash_files{$key}{'max_size'};
            if($hash_files{$key}{'max_size'} > $max)
            {
                $max = $hash_files{$key}{'max_size'};
            }
        }
    }
}
if($counter > 0) { $avg = $sum / $counter; }
else { $avg = 0; }
$avg = format_bytes($avg);
$max = format_bytes($max);
print FILE_CNT_TABLE "write-only files \& $counter \& $avg \& $max \\\\\n";

$counter = 0;
$sum = 0;
$max = 0;
foreach $key (keys %hash_files) {
    if($hash_files{$key}{'was_read'} && $hash_files{$key}{'was_written'})
    {
        $counter++;
        if($hash_files{$key}{'min_open_size'} >
            $hash_files{$key}{'max_size'})
        {
            $sum += $hash_files{$key}{'min_open_size'};
            if($hash_files{$key}{'min_open_size'} > $max)
            {
                $max = $hash_files{$key}{'min_open_size'};
            }
        }
        else
        {
            $sum += $hash_files{$key}{'max_size'};
            if($hash_files{$key}{'max_size'} > $max)
            {
                $max = $hash_files{$key}{'max_size'};
            }
        }
    }
}
if($counter > 0) { $avg = $sum / $counter; }
else { $avg = 0; }
$avg = format_bytes($avg);
$max = format_bytes($max);
print FILE_CNT_TABLE "read/write files \& $counter \& $avg \& $max \\\\\n";

$counter = 0;
$sum = 0;
$max = 0;
foreach $key (keys %hash_files) {
    if($hash_files{$key}{'was_written'} &&
        $hash_files{$key}{'min_open_size'} == 0 &&
        $hash_files{$key}{'max_size'} > 0)
    {
        $counter++;
        if($hash_files{$key}{'min_open_size'} >
            $hash_files{$key}{'max_size'})
        {
            $sum += $hash_files{$key}{'min_open_size'};
            if($hash_files{$key}{'min_open_size'} > $max)
            {
                $max = $hash_files{$key}{'min_open_size'};
            }
        }
        else
        {
            $sum += $hash_files{$key}{'max_size'};
            if($hash_files{$key}{'max_size'} > $max)
            {
                $max = $hash_files{$key}{'max_size'};
            }
        }
    }
}
if($counter > 0) { $avg = $sum / $counter; }
else { $avg = 0; }
$avg = format_bytes($avg);
$max = format_bytes($max);
print FILE_CNT_TABLE "created files \& $counter \& $avg \& $max \\\\\n";

print FILE_CNT_TABLE "
\\hline
\\end{tabular}
";
close(FILE_CNT_TABLE);

# generate per filesystem data
open(FS_TABLE, ">$tmp_dir/fs-data-table.tex") || die("error opening output files:$!\n");
print FS_TABLE "
\\begin{tabular}{c|r|r|r|r}
\\multicolumn{5}{c}{ } \\\\
\\multicolumn{5}{c}{Data Transfer Per Filesystem (POSIX and STDIO)} \\\\
\\hline
\\multirow{2}{*}{File System} \& \\multicolumn{2}{c}{Write} \\vline \& \\multicolumn{2}{c}{Read} \\\\
\\cline{2-5}
\& MiB \& Ratio \& MiB \& Ratio \\\\\
\\hline
\\hline
";

foreach $key (keys %fs_data)
{
    my $wr_total_mb = ($fs_data{$key}->[1] / (1024*1024));
    my $rd_total_mb = ($fs_data{$key}->[0] / (1024*1024));

    my $wr_total_rt;
    if ($cumul_write_bytes_shared+$cumul_write_bytes_indep)
    {
        $wr_total_rt = ($fs_data{$key}->[1] / ($cumul_write_bytes_shared + $cumul_write_bytes_indep));
    }
    else
    {
        $wr_total_rt = 0;
    }

    my $rd_total_rt;
    if ($cumul_read_bytes_shared+$cumul_read_bytes_indep)
    {
        $rd_total_rt = ($fs_data{$key}->[0] / ($cumul_read_bytes_shared + $cumul_read_bytes_indep));
    }
    else
    {
        $rd_total_rt = 0;
    }

    printf FS_TABLE "%s \& %.5f \& %.5f \& %.5f \& %.5f \\\\\n",
        $key, $wr_total_mb, $wr_total_rt, $rd_total_mb, $rd_total_rt;
}

print FS_TABLE "
\\hline
\\end{tabular}
";
close FS_TABLE;

# variance data
open(VAR_TABLE, ">$tmp_dir/variance-table.tex") || die("error opening output file:$!\n");
print VAR_TABLE "
\\begin{tabular}{c|r|r|r|r|r|r|r|r|r}
\\multicolumn{10}{c}{} \\\\
\\multicolumn{10}{c}{Variance in Shared Files (POSIX and STDIO)} \\\\
\\hline
File \& Processes \& \\multicolumn{3}{c}{Fastest} \\vline \&
\\multicolumn{3}{c}{Slowest} \\vline \& \\multicolumn{2}{c}{\$\\sigma\$} \\\\
\\cline{3-10}
Suffix \&  \& Rank \& Time \& Bytes \& Rank \& Time \& Bytes \& Time \& Bytes \\\\
\\hline
\\hline
";

my $curcount = 1;
foreach $key (sort { $hash_files{$b}{'slowest_time'} <=> $hash_files{$a}{'slowest_time'} } keys %hash_files) {

    if ($curcount > 20) { last; }

    if ($hash_files{$key}{'procs'} > 1)
    {
        my $vt = sprintf("%.3g", sqrt($hash_files{$key}{'variance_time'}));
        my $vb = sprintf("%.3g", sqrt($hash_files{$key}{'variance_bytes'}));
        my $fast_bytes = format_bytes($hash_files{$key}{'fastest_bytes'});
        my $slow_bytes = format_bytes($hash_files{$key}{'slowest_bytes'});
        my $name = encode('latex', "..." . substr($hash_files{$key}{'name'}, -12));

        print VAR_TABLE "
               $name \&
               $hash_files{$key}{'procs'} \&
               $hash_files{$key}{'fastest_rank'} \&
               $hash_files{$key}{'fastest_time'} \&
               $fast_bytes \&
               $hash_files{$key}{'slowest_rank'} \&
               $hash_files{$key}{'slowest_time'} \&
               $slow_bytes \&
               $vt \&
               $vb \\\\
         ";
        $curcount++;
    }
}

print VAR_TABLE "
\\hline
\\end{tabular}
";
close VAR_TABLE;

# calculate performance
##########################################################################

# what was the slowest time by any proc for unique file access?
my $slowest_uniq_time = 0;
if(keys %hash_unique_file_time > 0)
{
    $slowest_uniq_time < $_ and $slowest_uniq_time = $_ for values %hash_unique_file_time;
}
print("Slowest unique file time: $slowest_uniq_time\n");
print("Slowest shared file time: $shared_file_time\n");
print("Total bytes read and written by app (may be incorrect): $total_job_bytes\n");
my $tmp_total_time = $slowest_uniq_time+$shared_file_time;
print("Total absolute I/O time: $tmp_total_time\n");
print("**NOTE: above shared and unique file times calculated using MPI-IO timers if MPI-IO interface used on a given file, POSIX timers otherwise.\n");

#Exit here if user ask only for a summary
if ($summary_flag)
{
        exit(0);
}

# move to tmp_dir
chdir $tmp_dir;

# gather data to be used for document title (headers/footers)
($executable, $junk) = split(' ', $cmdline, 2);
@parts = split('/', $executable);
$cmd = $parts[$#parts];
@timearray = localtime($starttime);
$year = $timearray[5] + 1900;
$mon = $timearray[4] + 1;
$mday = $timearray[3];

# detect gnuplot ranges for file access graphs
my $ymax = $nprocs;
my $yinc = int($nprocs / 8);
if($yinc == 0) {$yinc=1;}
my $ymaxtic = $nprocs-1;

# reformat cumulative i/o data for file access table
my $cri = $cumul_read_indep / $nprocs;
my $crbi = $cumul_read_bytes_indep / ($nprocs * 1048576.0);

my $cwi = $cumul_write_indep / $nprocs;
my $cwbi = $cumul_write_bytes_indep / ($nprocs * 1048576.0);

my $crs = $cumul_read_shared / $nprocs;
my $crbs = $cumul_read_bytes_shared / ($nprocs * 1048576.0);

my $cws = $cumul_write_shared / $nprocs;
my $cwbs = $cumul_write_bytes_shared / ($nprocs * 1048576.0);

my $cmi = $cumul_meta_indep / $nprocs;
my $cms = $cumul_meta_shared / $nprocs;

# do any extra work needed for plotting mpi-io graphs
if (defined $summary{MPIIO_INDEP_OPENS})
{
    system "$gnuplot -e \"data_file='mpiio-access-hist.dat'; graph_title='MPI-IO Access Sizes {/Times-Bold=32 \263}'; \\
    output_file='mpiio-access-hist.eps'\" access-hist-eps.gplt";
    system "$epstopdf mpiio-access-hist.eps";

    open(OP_COUNTS_PLT, ">>$tmp_dir/op-counts-eps.gplt") || die("error opening output file: $!\n");
    my $tmp_sz = -s "$tmp_dir/op-counts-eps.gplt";
    # overwrite existing newline
    truncate(OP_COUNTS_PLT, $tmp_sz-1);
    print OP_COUNTS_PLT ", \\
    \"mpiio-op-counts.dat\" using 2:xtic(1) title \"MPI-IO Indep.\", \\
    \"\" using 3 title \"MPI-IO Coll.\"\n";
    close OP_COUNTS_PLT;
}

# do any extra work needed for plotting stdio graphs
if (defined $summary{STDIO_OPENS})
{
    open(OP_COUNTS_PLT, ">>$tmp_dir/op-counts-eps.gplt") || die("error opening output file: $!\n");
    my $tmp_sz = -s "$tmp_dir/op-counts-eps.gplt";
    # overwrite existing newline
    truncate(OP_COUNTS_PLT, $tmp_sz-1);
    print OP_COUNTS_PLT ", \\
    \"stdio-op-counts.dat\" using 2:xtic(1) title \"STDIO\"\n";
    close OP_COUNTS_PLT;
}

# execute base gnuplot scripts
system "$gnuplot time-summary-eps.gplt";
system "$epstopdf time-summary.eps";
system "$gnuplot op-counts-eps.gplt";
system "$epstopdf op-counts.eps";
system "$gnuplot -e \"data_file='posix-access-hist.dat'; graph_title='POSIX Access Sizes'; \\
output_file='posix-access-hist.eps'\" access-hist-eps.gplt";
system "$epstopdf posix-access-hist.eps";
system "$gnuplot -e \"ymax=$ymax; yinc=$yinc; ymaxtic=$ymaxtic; runtime='$runtime'\" file-access-eps.gplt";
system "$epstopdf file-access-read.eps";
system "$epstopdf file-access-write.eps";
system "$epstopdf file-access-shared.eps";
system "$gnuplot pattern-eps.gplt";
system "$epstopdf pattern.eps";

# generate summary PDF
# NOTE: we pass arguments to the latex template using '\def' commands
# NOTE: an autoconf test determines if -halt-on-error is available and sets
# __DARSHAN_PDFLATEX_HALT_ON_ERROR accordingly
my $latex_cmd_line = "\"\\def\\titlecmd{$cmd} \\
    \\def\\titlemon{$mon} \\
    \\def\\titlemday{$mday} \\
    \\def\\titleyear{$year} \\
    \\def\\titlecmdline{$cmdline} \\
    \\def\\jobid{$jobid} \\
    \\def\\jobuid{$uid} \\
    \\def\\jobnprocs{$nprocs} \\
    \\def\\jobruntime{$runtime} \\
    \\def\\filecri{$cri} \\
    \\def\\filecrbi{$crbi} \\
    \\def\\filecwi{$cwi} \\
    \\def\\filecwbi{$cwbi} \\
    \\def\\filecrs{$crs} \\
    \\def\\filecrbs{$crbs} \\
    \\def\\filecws{$cws} \\
    \\def\\filecwbs{$cwbs} \\
    \\def\\filecmi{$cmi} \\
    \\def\\filecms{$cms} \\
    \\def\\filecmi{$cmi} \\
    \\def\\perflayer{$perf_layer} \\
    \\def\\perfest{$perf_est} \\
    \\def\\perfbytes{$perf_mbytes} \\
    \\def\\stdioperfest{$stdio_perf_est} \\
    \\def\\stdioperfbytes{$stdio_perf_mbytes} \\
    \\input{summary.tex}\" \\
    -halt-on-error";

if ($partial_flag == 1)
{
    my $partial_log_flags = "\\def\\incompletelog{1} \\";
    $latex_cmd_line = substr($latex_cmd_line, 0, 1) . $partial_log_flags . substr($latex_cmd_line, 1);
}

if (defined $summary{MPIIO_INDEP_OPENS})
{
    my $mpiio_latex_flags = "\\def\\inclmpiio{1} \\";
    $latex_cmd_line = substr($latex_cmd_line, 0, 1) . $mpiio_latex_flags . substr($latex_cmd_line, 1);
}

if($perf_est > 0)
{
    my $perf_latex_flags = "\\def\\inclperf{1} \\";
    $latex_cmd_line = substr($latex_cmd_line, 0, 1) . $perf_latex_flags . substr($latex_cmd_line, 1);

}

if($stdio_perf_est > 0)
{
    my $stdio_latex_flags = "\\def\\inclstdio{1} \\";
    $latex_cmd_line = substr($latex_cmd_line, 0, 1) . $stdio_latex_flags . substr($latex_cmd_line, 1);

}

$system_rc = system "$pdflatex $latex_cmd_line > latex.output";
if($system_rc)
{
    print("LaTeX generation (phase1) failed [$system_rc], aborting summary creation.\n");
    print("error log:\n");
    system("tail latex.output");
    exit(1);
}
$system_rc = system "$pdflatex $latex_cmd_line > latex.output2";
if($system_rc)
{
    print("LaTeX generation (phase2) failed [$system_rc], aborting summary creation.\n");
    print("error log:\n");
    system("tail latex.output2");
    exit(1);
}

# get back out of tmp dir and grab results
chdir $orig_dir;
system "$mv $tmp_dir/summary.pdf $output_file";


sub process_file_record
{
    my $hash = $_[0];
    my(%file_record) = %{$_[1]};
    my $rank = $file_record{'RANK'};

    if(!defined $file_record{'POSIX_OPENS'} && !defined $file_record{'STDIO_OPENS'})
    {
        # ignore data records that don't have POSIX & MPI data
        return;
    }

    if((!defined $file_record{'POSIX_OPENS'} || $file_record{'POSIX_OPENS'} == 0) &&
        (!defined $file_record{'STDIO_OPENS'} || $file_record{'STDIO_OPENS'} == 0) &&
        (!defined $file_record{'MPIIO_INDEP_OPENS'} ||
        ($file_record{'MPIIO_INDEP_OPENS'} == 0 && $file_record{'MPIIO_COLL_OPENS'} == 0)))
    {
        # file wasn't really opened, just stat probably
        return;
    }

    # record smallest open time size reported by any rank
    # XXX this isn't doable since dropping SIZE_AT_OPEN counter
    $hash_files{$hash}{'min_open_size'} = 0;

    # record largest size that the file reached at any rank
    if(defined $file_record{'POSIX_OPENS'})
    {
        if(!defined($hash_files{$hash}{'max_size'}) ||
            $hash_files{$hash}{'max_size'} <  
            ($file_record{'POSIX_MAX_BYTE_READ'} + 1))
        {
            $hash_files{$hash}{'max_size'} = 
                $file_record{'POSIX_MAX_BYTE_READ'} + 1;
        }
        if(!defined($hash_files{$hash}{'max_size'}) ||
            $hash_files{$hash}{'max_size'} <  
            ($file_record{'POSIX_MAX_BYTE_WRITTEN'} + 1))
        {
            $hash_files{$hash}{'max_size'} = 
                $file_record{'POSIX_MAX_BYTE_WRITTEN'} + 1;
        }
    }

    # for stdio as well
    if(defined $file_record{'STDIO_OPENS'})
    {
        if(!defined($hash_files{$hash}{'max_size'}) ||
            $hash_files{$hash}{'max_size'} <  
            ($file_record{'STDIO_MAX_BYTE_READ'} + 1))
        {
            $hash_files{$hash}{'max_size'} = 
                $file_record{'STDIO_MAX_BYTE_READ'} + 1;
        }
        if(!defined($hash_files{$hash}{'max_size'}) ||
            $hash_files{$hash}{'max_size'} <  
            ($file_record{'STDIO_MAX_BYTE_WRITTEN'} + 1))
        {
            $hash_files{$hash}{'max_size'} = 
                $file_record{'STDIO_MAX_BYTE_WRITTEN'} + 1;
        }
    }

    # make sure there is an initial value for read and write flags
    if(!defined($hash_files{$hash}{'was_read'}))
    {
        $hash_files{$hash}{'was_read'} = 0;
    }
    if(!defined($hash_files{$hash}{'was_written'}))
    {
        $hash_files{$hash}{'was_written'} = 0;
    }

    if(defined $file_record{'MPIIO_INDEP_OPENS'} &&
        ($file_record{'MPIIO_INDEP_OPENS'} > 0 ||
        $file_record{'MPIIO_COLL_OPENS'} > 0))
    {
        # mpi file
        if($file_record{'MPIIO_INDEP_READS'} > 0 ||
            $file_record{'MPIIO_COLL_READS'} > 0 ||
            $file_record{'MPIIO_SPLIT_READS'} > 0 ||
            $file_record{'MPIIO_NB_READS'} > 0)
        {
            # data was read from the file
            $hash_files{$hash}{'was_read'} = 1;
        }
        if($file_record{'MPIIO_INDEP_WRITES'} > 0 ||
            $file_record{'MPIIO_COLL_WRITES'} > 0 ||
            $file_record{'MPIIO_SPLIT_WRITES'} > 0 ||
            $file_record{'MPIIO_NB_WRITES'} > 0)
        {
            # data was written to the file
            $hash_files{$hash}{'was_written'} = 1;
        }
    }
    else
    {
        # posix file
        if((defined $file_record{'POSIX_READS'} && $file_record{'POSIX_READS'} > 0) || (defined $file_record{'STDIO_READS'} && $file_record{'STDIO_READS'} > 0))
        {
            # data was read from the file
            $hash_files{$hash}{'was_read'} = 1;
        }
        if((defined $file_record{'POSIX_WRITES'} && $file_record{'POSIX_WRITES'} > 0) || (defined $file_record{'STDIO_WRITES'} && $file_record{'STDIO_WRITES'} > 0))
        {
            # data was written to the file 
            $hash_files{$hash}{'was_written'} = 1;
        }
    }

    $hash_files{$hash}{'name'} = $file_record{FILE_NAME};

    if ($rank == -1)
    {
        if(defined $file_record{'POSIX_OPENS'} && $file_record{'POSIX_OPENS'} > 0)
        {
            $hash_files{$hash}{'procs'}          = $nprocs;
            $hash_files{$hash}{'slowest_rank'}   = $file_record{'POSIX_SLOWEST_RANK'};
            $hash_files{$hash}{'slowest_time'}   = $file_record{'POSIX_F_SLOWEST_RANK_TIME'};
            $hash_files{$hash}{'slowest_bytes'}  = $file_record{'POSIX_SLOWEST_RANK_BYTES'};
            $hash_files{$hash}{'fastest_rank'}   = $file_record{'POSIX_FASTEST_RANK'};
            $hash_files{$hash}{'fastest_time'}   = $file_record{'POSIX_F_FASTEST_RANK_TIME'};
            $hash_files{$hash}{'fastest_bytes'}  = $file_record{'POSIX_FASTEST_RANK_BYTES'};
            $hash_files{$hash}{'variance_time'}  = $file_record{'POSIX_F_VARIANCE_RANK_TIME'};
            $hash_files{$hash}{'variance_bytes'} = $file_record{'POSIX_F_VARIANCE_RANK_BYTES'};
        }
        elsif(defined $file_record{'STDIO_OPENS'} && $file_record{'STDIO_OPENS'} > 0)
        {
            $hash_files{$hash}{'procs'}          = $nprocs;
            $hash_files{$hash}{'slowest_rank'}   = $file_record{'STDIO_SLOWEST_RANK'};
            $hash_files{$hash}{'slowest_time'}   = $file_record{'STDIO_F_SLOWEST_RANK_TIME'};
            $hash_files{$hash}{'slowest_bytes'}  = $file_record{'STDIO_SLOWEST_RANK_BYTES'};
            $hash_files{$hash}{'fastest_rank'}   = $file_record{'STDIO_FASTEST_RANK'};
            $hash_files{$hash}{'fastest_time'}   = $file_record{'STDIO_F_FASTEST_RANK_TIME'};
            $hash_files{$hash}{'fastest_bytes'}  = $file_record{'STDIO_FASTEST_RANK_BYTES'};
            $hash_files{$hash}{'variance_time'}  = $file_record{'STDIO_F_VARIANCE_RANK_TIME'};
            $hash_files{$hash}{'variance_bytes'} = $file_record{'STDIO_F_VARIANCE_RANK_BYTES'};
        }
    }
    else
    {
        my $total_time = 0;
        my $total_bytes = 0;

        if(defined $file_record{'POSIX_OPENS'})
        {
            $total_time += $file_record{'POSIX_F_META_TIME'} +
                         $file_record{'POSIX_F_READ_TIME'} +
                         $file_record{'POSIX_F_WRITE_TIME'};
            $total_bytes += $file_record{'POSIX_BYTES_READ'} +
                          $file_record{'POSIX_BYTES_WRITTEN'};
        }
        if(defined $file_record{'STDIO_OPENS'})
        {
            $total_time += $file_record{'STDIO_F_META_TIME'} +
                         $file_record{'STDIO_F_READ_TIME'} +
                         $file_record{'STDIO_F_WRITE_TIME'};
            $total_bytes += $file_record{'STDIO_BYTES_READ'} +
                          $file_record{'STDIO_BYTES_WRITTEN'};
        }

        if(!defined($hash_files{$hash}{'slowest_time'}) ||
           $hash_files{$hash}{'slowest_time'} < $total_time)
        {
            $hash_files{$hash}{'slowest_time'}  = $total_time;
            $hash_files{$hash}{'slowest_rank'}  = $rank;
            $hash_files{$hash}{'slowest_bytes'} = $total_bytes;
        }

        if(!defined($hash_files{$hash}{'fastest_time'}) ||
           $hash_files{$hash}{'fastest_time'} > $total_time)
        {
            $hash_files{$hash}{'fastest_time'}  = $total_time;
            $hash_files{$hash}{'fastest_rank'}  = $rank;
            $hash_files{$hash}{'fastest_bytes'} = $total_bytes;
        }

        if(!defined($hash_files{$hash}{'variance_time_S'}))
        {
            $hash_files{$hash}{'variance_time_S'} = 0;
            $hash_files{$hash}{'variance_time_T'} = $total_time;
            $hash_files{$hash}{'variance_time_n'} = 1;
            $hash_files{$hash}{'variance_bytes_S'} = 0;
            $hash_files{$hash}{'variance_bytes_T'} = $total_bytes;
            $hash_files{$hash}{'variance_bytes_n'} = 1;
            $hash_files{$hash}{'procs'} = 1;
            $hash_files{$hash}{'variance_time'} = 0;
            $hash_files{$hash}{'variance_bytes'} = 0;
        }
        else
        {
            my $n = $hash_files{$hash}{'variance_time_n'};
            my $m = 1;
            my $T = $hash_files{$hash}{'variance_time_T'};
            $hash_files{$hash}{'variance_time_S'} += ($m/($n*($n+$m)))*(($n/$m)*$total_time - $T)*(($n/$m)*$total_time - $T);
            $hash_files{$hash}{'variance_time_T'} += $total_time;
            $hash_files{$hash}{'variance_time_n'} += 1;

            $hash_files{$hash}{'variance_time'}    = $hash_files{$hash}{'variance_time_S'} / $hash_files{$hash}{'variance_time_n'};

            $n = $hash_files{$hash}{'variance_bytes_n'};
            $m = 1;
            $T = $hash_files{$hash}{'variance_bytes_T'};
            $hash_files{$hash}{'variance_bytes_S'} += ($m/($n*($n+$m)))*(($n/$m)*$total_bytes - $T)*(($n/$m)*$total_bytes - $T);
            $hash_files{$hash}{'variance_bytes_T'} += $total_bytes;
            $hash_files{$hash}{'variance_bytes_n'} += 1;

            $hash_files{$hash}{'variance_bytes'}    = $hash_files{$hash}{'variance_bytes_S'} / $hash_files{$hash}{'variance_bytes_n'};

            $hash_files{$hash}{'procs'} = $hash_files{$hash}{'variance_time_n'};
        }
    }

    # if this is a non-shared file, then add the time spent here to the
    # total for that particular rank
    # XXX mpiio or posix? should we do both or just pick mpiio over posix?
    if ($rank != -1)
    {
        # is it mpi-io or posix?
        if(defined $file_record{MPIIO_INDEP_OPENS} &&
            ($file_record{MPIIO_INDEP_OPENS} > 0 ||
            $file_record{MPIIO_COLL_OPENS} > 0))
        {
            # add up mpi times
            if(defined($hash_unique_file_time{$rank}))
            {
                $hash_unique_file_time{$rank} +=
                    $file_record{MPIIO_F_META_TIME} + 
                    $file_record{MPIIO_F_READ_TIME} + 
                    $file_record{MPIIO_F_WRITE_TIME};
            }
            else
            {
                $hash_unique_file_time{$rank} =
                    $file_record{MPIIO_F_META_TIME} + 
                    $file_record{MPIIO_F_READ_TIME} + 
                    $file_record{MPIIO_F_WRITE_TIME};
            }
        }
        else
        {
            if(defined($file_record{POSIX_OPENS}))
            {
                # add up posix times
                if(defined($hash_unique_file_time{$rank}))
                {
                    $hash_unique_file_time{$rank} +=
                        $file_record{POSIX_F_META_TIME} + 
                        $file_record{POSIX_F_READ_TIME} + 
                        $file_record{POSIX_F_WRITE_TIME};
                }
                else
                {
                    $hash_unique_file_time{$rank} =
                        $file_record{POSIX_F_META_TIME} + 
                        $file_record{POSIX_F_READ_TIME} + 
                        $file_record{POSIX_F_WRITE_TIME};
                }
            }
            if(defined($file_record{STDIO_OPENS}))
            {
                # add up posix times
                if(defined($hash_unique_file_time{$rank}))
                {
                    $hash_unique_file_time{$rank} +=
                        $file_record{STDIO_F_META_TIME} + 
                        $file_record{STDIO_F_READ_TIME} + 
                        $file_record{STDIO_F_WRITE_TIME};
                }
                else
                {
                    $hash_unique_file_time{$rank} =
                        $file_record{STDIO_F_META_TIME} + 
                        $file_record{STDIO_F_READ_TIME} + 
                        $file_record{STDIO_F_WRITE_TIME};
                }
            }
        }
    }
    else
    {
        # cumulative time spent on shared files by slowest proc
        # is it mpi-io or posix?
        if(defined $file_record{MPIIO_INDEP_OPENS} &&
            ($file_record{MPIIO_INDEP_OPENS} > 0 ||
            $file_record{MPIIO_COLL_OPENS} > 0))
        {
            $shared_file_time += $file_record{'MPIIO_F_SLOWEST_RANK_TIME'};
        }
        else
        {
            if(defined $file_record{'POSIX_OPENS'} && $file_record{'POSIX_OPENS'} > 0)
            {
                $shared_file_time += $file_record{'POSIX_F_SLOWEST_RANK_TIME'};
            }
            elsif(defined $file_record{'STDIO_OPENS'} && $file_record{'STDIO_OPENS'} > 0)
            {
                $shared_file_time += $file_record{'STDIO_F_SLOWEST_RANK_TIME'};
            }
        }
    }

    my $mpi_did_read = 0;
    if (defined $file_record{MPIIO_INDEP_OPENS})
    {
        $mpi_did_read =
            $file_record{'MPIIO_INDEP_READS'} + 
            $file_record{'MPIIO_COLL_READS'} + 
            $file_record{'MPIIO_NB_READS'} + 
            $file_record{'MPIIO_SPLIT_READS'};
    }

    # add up how many bytes were transferred
    if(defined $file_record{MPIIO_INDEP_OPENS} &&
        ($file_record{MPIIO_INDEP_OPENS} > 0 ||
        $file_record{MPIIO_COLL_OPENS} > 0) && (!($mpi_did_read)))
    {
        # mpi file that was only written; disregard any read accesses that
        # may have been performed for sieving at the posix level
        $total_job_bytes += $file_record{'POSIX_BYTES_WRITTEN'}; 
    }
    else
    {
        # normal case
        if(defined $file_record{'POSIX_OPENS'})
        {
            $total_job_bytes += $file_record{'POSIX_BYTES_WRITTEN'} +
                $file_record{'POSIX_BYTES_READ'};
        }
        if(defined $file_record{'STDIO_OPENS'})
        {
            $total_job_bytes += $file_record{'STDIO_BYTES_WRITTEN'} +
            $file_record{'STDIO_BYTES_READ'};
        }
    }
}

sub process_args
{
    use vars qw( $opt_help $opt_output $opt_verbose $opt_summary);

    Getopt::Long::Configure("no_ignore_case", "bundling");
    GetOptions( "help",
        "output=s",
        "verbose",
        "summary");

    if($opt_help)
    {
        print_help();
        exit(0);
    }

    if($opt_output)
    {
        $output_file = $opt_output;
    }

    if($opt_verbose)
    {
        $verbose_flag = $opt_verbose;
    }

    if($opt_summary)
    {
        $summary_flag = $opt_summary;
    }
    
    # there should only be one remaining argument: the input file 
    if($#ARGV != 0)
    {
        print "Error: invalid arguments.\n";
        print_help();
        exit(1);
    }

    $input_file = $ARGV[0];

    # give default output file a similar name to the input file.
    #   log_name => log_name.pdf
    if (not $opt_output)
    {
        $output_file = basename($input_file);
        $output_file .= ".pdf";
    }

    return;
}

#
# Check for all support programs needed to generate the summary.
#
sub check_prereqs
{
    my $rc;
    my $output;
    my @bins = ($darshan_parser, $pdflatex, $epstopdf,
                $gnuplot, $cp, $mv);
    foreach my $bin (@bins)
    {
        $rc = checkbin($bin);
        if ($rc)
        {
            print("error: $bin not found in PATH\n");
            exit(1);
        }
    }

    # check gnuplot version
    $output = `$gnuplot --version`;
    if($? != 0)
    {
        print("error: failed to execute $gnuplot.\n");
        exit(1);
    }

    $output =~ /gnuplot (\d+)\.(\d+)/;
    if($1 < 4 || ($1 < 5 && $2 < 2))
    {
        print("error: detected $gnuplot version $1.$2, but darshan-job-summary requires at least 4.2.\n");
        exit(1);
    }

    return;
}

#
# Execute which to see if the binary can be found in
# the users path.
#
sub checkbin($)
{
    my $binname = shift;
    my $rc;

    # save stdout/err
    open(SAVEOUT, ">&STDOUT");
    open(SAVEERR, ">&STDERR");

    # redirect stdout/error
    open(STDERR, '>/dev/null');
    open(STDOUT, '>/dev/null');
    $rc = system("which $binname");
    if ($rc)
    {
        $rc = 1;
    }
    close(STDOUT);
    close(STDERR);

    # suppress perl warning
    select(SAVEERR);
    select(SAVEOUT);

    # restore stdout/err
    open(STDOUT, ">&SAVEOUT");
    open(STDERR, ">&SAVEERR");

    return $rc;
}

sub print_help
{
    print <<EOF;

Usage: $PROGRAM_NAME <options> input_file

    --help          Prints this help message
    --output        Specifies a file to write pdf output to
                    (defaults to ./summary.pdf)
    --summary       Print a very succinct I/O timing summary and exit
    --verbose       Prints and retains tmpdir used for LaTeX output

Purpose:

    This script reads a Darshan output file generated by a job and
    generates a pdf file summarizing job behavior.

EOF
    return;
}
