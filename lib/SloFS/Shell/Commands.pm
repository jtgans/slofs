#!/usr/bin/perl -w
#
# Copyright (C) 2007  June Tate-Gans, All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package SloFS::Shell::Commands;

use strict;
use English;
use Data::Dumper;

use DBI;

use SloFS::Lib;

# my $slofs_handle = {
#     "dbh" => undef,
#     "filename" => undef,
#     "label" => undef,
#     "version" => [],
#     "clean" => undef,
# };

sub mount {
    my $path = shift;

    if (! -f $path) {
        die "mount: blob file `${path}' does not exist.\n"
    }

    $SloFS::Shell::SLOFS_HANDLE = SloFS::Lib::mount($path);

    if (!$SloFS::Shell::SLOFS_HANDLE) {
        die "mount: unable to mount filesystem: $EVAL_ERROR\n"
    }
}

sub umount {
    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "umount: not mounted\n";
    }

    SloFS::Lib::umount($SloFS::Shell::SLOFS_HANDLE);
    $SloFS::Shell::SLOFS_HANDLE = undef;
}

sub cd {
    my $path = shift;

    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "cd: not mounted\n";
    }

    SloFS::Lib::chdir($path);
}

sub ls {
    my $path = undef;
    my $dh = undef;

    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "ls: not mounted\n";
    }

    if (defined($ARG[0])) {
        $path = shift;
    } else {
        $path = SloFS::Lib::getcwd($SloFS::Shell::SLOFS_HANDLE);
    }

    $dh = SloFS::Lib::opendir($SloFS::Shell::SLOFS_HANDLE, $path);

    if (!$dh) {
        die "ls: Unable to read `${path}': ${EVAL_ERROR}\n";
    }

    while (my $dirent = SloFS::Lib::readdir($dh)) {
        my $stat = SloFS::Lib::stat_file($SloFS::Shell::SLOFS_HANDLE, $dirent);

        if (!$stat) {
            print "ls: Unable to stat file `$dirent'\n";
        } else {
            print $dirent;
            print "/" if $stat->{"type"} eq "directory";
            print "\n";
        }
    }

    SloFS::Lib::closedir($dh);
}

sub rm {
    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "rm: not mounted\n";
    }

    for my $file (@ARG) {
        SloFS::Lib::unlink($SloFS::Shell::SLOFS_HANDLE, $file);
    }
}

sub cp {
    my $src = shift;
    my $dst = shift;
    my $src_stat = undef;
    my $dst_stat = undef;
    my $src_fh = undef;
    my $dst_fh = undef;

    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "cp: not mounted\n";
    }
    
    $src_stat = SloFS::Lib::stat_file($src);
    $src_fh = SloFS::Lib::open($SloFS::Shell::SLOFS_HANDLE, $src, "r");

    if (!defined($src_stat)) {
        die "cp: unable to stat file `${src}'.\n";
    }

    if ($src_stat->{"type"} eq "dir") {
        die "cp: source file `${src}' is a directory.\n";
    }

    if (!defined($src_fh)) {
        die "cp: unable to open `${src}' for reading.\n";
    }

    $dst_stat = SloFS::Lib::stat_file($dst);

    if ((!defined($dst_stat)) or ($dst_stat->{"type"} eq "file")) {
        # new file -- create it
        $dst_fh = SloFS::Lib::open($SloFS::Shell::SLOFS_HANDLE, $dst, "w");
    } else {
        # directory -- check to see if it contains a file by the same
        # name. if so, overwrite it. if not, create a new file of the
        # source name.
        
        $dst_stat = SloFS::Lib::stat_file($dst ."/". basename($src));
    }

    
}

sub touch {
    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "touch: not mounted\n";
    }

    for my $file (@ARG) {
        my $stat = SloFS::Lib::stat_file($SloFS::Shell::SLOFS_HANDLE, $file);

        if ($stat) {
            my $result = SloFS::Lib::utime($SloFS::Shell::SLOFS_HANDLE, $file, time);

            if (!$result) {
                die "touch: unable to update time on file `${file}'\n";
            }
        } else {
            my $fh = SloFS::Lib::open($SloFS::Shell::SLOFS_HANDLE, $file, "w");

            if ($fh) {
                SloFS::Lib::close($fh);
            } else {
                die "touch: unable to open file `${file}'\n";
            }
        }
    }
}

sub stat {
    my $filename = shift;
    my $stat = undef;

    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "stat: not mounted\n";
    }

    $stat = SloFS::Lib::stat_file($SloFS::Shell::SLOFS_HANDLE, $filename);

    if (!$stat) {
        die "stat: unable to stat file `${filename}'\n";
    } else {
        for my $key (keys(%{$stat})) {
            printf("%s: %s\n", $key, $stat->{$key});
        }
    }
}

sub cat {
    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "cat: not mounted\n";
    }

    for my $filename (@ARG) {
        my $stat = SloFS::Lib::stat_file($SloFS::Shell::SLOFS_HANDLE, $filename);
        my $fh = SloFS::Lib::open($SloFS::Shell::SLOFS_HANDLE, $filename, "r");

        if (!$stat) {
            die "cat: unable to stat file `${filename}'\n";
        }

        if (!$fh) {
            die "cat: unable to open file `${filename}'\n";
        }

        print SloFS::Lib::read($fh, $stat->{"size"});
        SloFS::Lib::close($fh);
    }
}

# Does the opposite of cat -- writes to a file instead, hence the name
# "dog". --jtg 
sub dog {
    my $filename = shift;
    my $stat = undef;
    my $fh = undef;

    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "uncat: not mounted\n";
    }

    $stat = SloFS::Lib::stat_file($SloFS::Shell::SLOFS_HANDLE, $filename);
    
    if (!defined($stat)) {
        # New file -- create it
        $fh = SloFS::Lib::open($SloFS::Shell::SLOFS_HANDLE, $filename, "w");
    } elsif ($stat->{"type"} eq "file") {
        $fh = SloFS::Lib::open($SloFS::Shell::SLOFS_HANDLE, $filename, "w+");
    } else {
        die "dog: file `${filename}' is a directory\n";
    }

    if (!$fh) {
        die "dog: unable to open file `${filename}' for writing.\n";
    }

    while (!eof(STDIN)) {
        print "> ";

        my $line = <STDIN>;
        my $result = SloFS::Lib::write($fh, $line, length($line));

        if ($result < 0) {
            die "dog: unable to write to file `${filename}'.\n";
        }
    }

    SloFS::Lib::close($fh);
}

sub basename {
    print SloFS::Lib::basename(shift) ."\n";
}

sub pathname {
    print SloFS::Lib::pathname(shift) ."\n";
}

sub pwd {
    if (!defined($SloFS::Shell::SLOFS_HANDLE)) {
        die "pwd: not mounted\n";
    }

    print SloFS::Lib::getcwd($SloFS::Shell::SLOFS_HANDLE) ."\n";
}

sub exit {
    exit(0);
}

sub mhandle {
    print Dumper($SloFS::Shell::SLOFS_HANDLE) ."\n";
}

sub mkdir {
}

1;
