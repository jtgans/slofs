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

package SloFS::Lib;

use strict;
use English;
use Carp;

use DBI;

use Data::Dumper;

# my $SLOFS_BLOB = {
#     "filename" => undef,
#     "label" => undef,
#     "version" => [undef, undef, undef],
#     "clean" => undef,
#     "cwd_id" => 0,
#     "cwd_path" => undef,
# };

sub valid_handle {
    my $handle = shift;

    if (defined($handle) &&
        (ref $handle eq "HASH") &&
        defined($handle->{"dbh"})) {
        return 1;
    } else {
        return undef;
    }
}

sub eval_path {
    my $path = shift;
    my $context = shift;
    my $relative_path = undef;
    my @result = ();

    if (defined($context)) {
        if (substr($context, 0, 1) ne "/") {
            # relative context -- invalid!
            return undef;
        }

        if (substr($path, 0, 1) eq "/") {
            # $path is absolute -- ignore $context
            $relative_path = $path;
        } else {
            # $path is relative -- concatenate to $context

            # Chop off any trailing / in the context.
            chop $context if substr($context, -1) eq "/";
            $relative_path = $context ."/". $path;
        }
    } else {
        $relative_path = $path;
    }

    eval {
        for my $element (split(/\//, $relative_path)) {
            if (($element eq ".") or ($element eq "")) {
                next;
            } elsif ($element eq "..") {
                if (@result == 0) {
                    die "stack underflow"
                } else {
                    pop @result;
                }
            } else {
                push @result, $element;
            }
        }
    }; if ($EVAL_ERROR) {
        return undef;
    }

    $path = join("/", @result);
    $path = "/${path}" if substr($path, 0, 1) ne "/";
    chop $path if substr($path, -1, 1) eq "/";
    $path = "/" if $path eq "";

    return $path;
}

sub get_dir_id {
    my $handle = shift;
    my $path = shift;
    my $last_parent = 0;
    my $cwd = undef;

    if (!valid_handle($handle)) {
        croak("Invalid handle.\n");
    }

    $cwd = getcwd($handle);
    $path = eval_path($path, $cwd);
    
    if ($path eq '/') {
        return 0;
    }

    for my $element (split(/\//, $path)) {
        my $result = $handle->{'dbh'}->selectrow_hashref(
            "SELECT * FROM dirs WHERE parent_id=? AND name=?",
            undef, $last_parent, $element);

        if (!$result) {
            return -1;
        }

        $last_parent = $result->{"id"};
    }

    return $last_parent;
}

sub getcwd {
    my $handle = shift;

    if (!valid_handle($handle)) {
        croak("Invalid handle.\n");
    }

    return $handle->{"cwd_path"};
}

sub mount {
    my $filename = shift;
    my $result = undef;
    my $dbh = undef;
    my $handle = {
        "dbh" => undef,
        "filename" => undef,
        "label" => undef,
        "version" => [],
        "clean" => undef,
        "cwd_id" => 0,
        "cwd_path" => undef,
    };

    if (! -f $filename) {
        croak("Unable to find blob file `${filename}'\n");
    }

    eval {
        $dbh = DBI->connect("dbi:SQLite:dbname=${filename}", "", "",
                            { RaiseError => 1, AutoCommit => 0 });
    }; if ($EVAL_ERROR or (!defined($dbh))) {
        croak("Unable to mount blob file `${filename}': ${@}\n");
    }

    $result = $dbh->selectrow_hashref("SELECT * FROM metadata");

    $handle = {
        "dbh"      => $dbh,
        "filename" => $filename,
        "label"    => $result->{"label"},
        "version"  => [ $result->{"version_major"},
                        $result->{"version_minor"},
                        $result->{"version_teeny"} ],
        "cwd_id"   => 0,
        "cwd_path" => "/"
    };

    return $handle;
}

sub getlabel {
    my $handle = shift;

    if (!valid_handle($handle)) {
        croak("Invalid handle.\n");
    } else {
        return $handle->{"label"};
    }
}

sub getfilename {
    my $handle = shift;

    if (!valid_handle($handle)) {
        croak("Invalid handle.\n");
    } else {
        return $handle->{"filename"};
    }
}

sub umount {
    my $handle = shift;
    my $dbh = undef;

    if ((!defined($handle)) or (!defined($handle->{"dbh"}))) {
        croak("Invalid handle.\n");
    } else {
        $dbh = $handle->{"dbh"};
    }

    $dbh->disconnect();
    $handle->{"dbh"} = undef;
}

sub basename {
    my $path = shift;

    $path =~ s/.*\///;

    return $path;
}

sub pathname {
    my $path = shift;

    $path =~ s/\/[^\/]*$//;
    
    return $path;
}

sub stat_file {
    my $handle = shift;
    my $path = shift;
    my $dbh = undef;
    my $cwd = undef;
    my $stat_info = undef;
    my $dir_id = undef;
    my $filename = undef;

    if (!valid_handle($handle)) {
        return undef;
    }

    $dbh = $handle->{"dbh"};
    $cwd = getcwd($handle);
    $path = eval_path($path, $cwd);
    $dir_id = get_dir_id($handle, pathname($path));
    $filename = basename($path);

    eval {
        $stat_info = $dbh->selectrow_hashref(
            "SELECT id,dir_id,name,length(data) as length,ctime,mtime " .
            "FROM files WHERE dir_id=? AND name=?", undef,
            $dir_id, $filename);

        if (!$stat_info) {
            # Try again with a directory name
            $stat_info = $dbh->selectrow_hashref(
                "SELECT id,parent_id,name,length(name) as length,ctime,mtime " .
                "FROM dirs WHERE parent_id=? AND name=?", undef,
                $dir_id, $filename);

            if (!$stat_info) {
                return -1;
            } else {
                $stat_info->{"type"} = "directory";
            }
        } else {
            $stat_info->{"type"} = "file";
        }
    }; if ($EVAL_ERROR) {
        croak("Unable to execute queries: $EVAL_ERROR\n");
    }

    return $stat_info;
}

sub opendir {
    my $handle = shift;
    my $path = shift;
    my $stat = undef;
    my $dbh = undef;
    my $dh = undef;
    my $contents = undef;

    if (!valid_handle($handle)) {
        croak("Invalid handle.\n");
    }

    $dbh = $handle->{"dbh"};
    $stat = stat_file($handle, $path);

    if (!$stat) {
        $EVAL_ERROR = "No such file or directory.";
        return undef;
    }

    if ($stat->{"type"} ne "directory") {
        $EVAL_ERROR = "Not a directory.";
        return undef;
    }

    eval {
        my $files = $dbh->selectall_arrayref("SELECT name FROM files WHERE dir_id=?", undef, $stat->{"id"});
        my $dirs  = $dbh->selectall_arrayref("SELECT name FROM dirs WHERE parent_id=?", undef, $stat->{"id"});

        $contents = [];

        for my $item (@{$files}, @{$dirs}) {
            push @{$contents}, $item->[0] if $item->[0] ne '';
        }
    }; if ($EVAL_ERROR) {
        croak("Unable to execute queries: $EVAL_ERROR\n");
    }

    $dh = {
        "fsp" => $handle,
        "dirno" => $stat->{"fileno"},
        "contents" => $contents,
        "length" => scalar(@{$contents}),
        "pos" => 0,
    };

    return $dh;
}

sub readdir {
    my $dh = shift;
    my $pos = undef;
    my $result = undef;

    if ((!defined($dh)) ||
        (ref $dh ne "HASH") ||
        (!defined($dh->{"fsp"}))) {
        croak("Invalid directory handle.\n");
    }

    $pos = $dh->{"pos"}++;
    $result = $dh->{"contents"}->[$pos];
    
    return $dh->{"contents"}->[$pos];
}

sub closedir {
    my $dh = shift;

    if ((!defined($dh)) ||
        (ref $dh ne "HASH") ||
        (!defined($dh->{"fsp"}))) {
        croak("Invalid directory handle.\n");
    }

    $dh->{"fsp"} = undef;

    return 1;
}

sub rewinddir {
    my $dh = shift;

    if ((!defined($dh)) ||
        (ref $dh ne "HASH") ||
        (!defined($dh->{"fsp"}))) {
        croak("Invalid directory handle.\n");
    }

    $dh->{"pos"} = 0;

    return 1;
}

1;
