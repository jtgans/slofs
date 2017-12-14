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

package SloFS::Shell;

use strict;
use English;
use UNIVERSAL "can";

use DBI;
use SloFS::Shell::Commands;
use SloFS::Lib;

our $SLOFS_HANDLE = undef;

sub print_pwd {
    my $root = "";

    if (defined($SLOFS_HANDLE)) {
        $root = SloFS::Lib::getlabel($SLOFS_HANDLE);
        $root = SloFS::Lib::getfilename($SLOFS_HANDLE) unless defined($root);
    } else {
        return "<not mounted>:/";
    }
    
    return $root .":". SloFS::Lib::getcwd($SLOFS_HANDLE);
}    

sub main {
    print("SloFS Experimental Shell v0.0.1\n\n");
    printf('%s$ ', print_pwd());

    while (<>) {
        chomp;

        my @cmdline = split(/ /);
        my @args = @cmdline[1,];
        my $cmd = $cmdline[0];

        if (defined($cmd)) {
            if (substr($cmd, 0, 1) eq "!") {
                my $shell_cmd = substr($cmd, 1) ." ";
                $shell_cmd .= join(" ", @args) if @args;

                system $shell_cmd;
            } elsif ($SloFS::Shell::Commands::{$cmd}) {
                eval {
                    $SloFS::Shell::Commands::{$cmd}(@args);
                }; if ($@) {
                    printf("%s", $@);
                }
            } else {
                printf("slofs: unknown command `%s'\n", $cmd);
            }
        }

        printf('%s$ ', print_pwd());
    }

    printf("exit\n");
}

1;
