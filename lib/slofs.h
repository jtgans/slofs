/*
 * Copyright (C) 2007  June Tate-Gans, All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#ifndef SLOFS_H
#define SLOFS_H

#define SLOFS_VERSION_MAJOR 0
#define SLOFS_VERSION_MINOR 0
#define SLOFS_VERSION_TEENY 1

typedef struct slofs_handle_t {
    char *filename;
    char *label;
    char version[3];
    char clean;
    long cwd_id;
} SLOFS;

typedef struct slofs_file_t {
    SLOFS *fsp;
    long fileno;
    long length;
    long pos;
} SLOFS_FILE;

enum slofs_file_type {
    FILE,
    DIR
};

typedef struct slofs_stat {
    char *filename;
    long fileno;
    long length;
    struct timespec ctime;
    struct timespec mtime;
    enum slofs_file_type type;
};

enum slofs_seek_whence {
    FORWARD,
    REWIND,
    ABSOLUTE
};

typedef struct slofs_dir_t {
    SLOFS *fsp;
    long dirno;
    long length;
    long pos;
} SLOFS_DIR;

extern int slofs_mkfs(const char *filename, const char *label);
extern SLOFS *slofs_mount(const char *filename);
extern int slofs_is_clean(SLOFS *fsp);
extern int slofs_unmount(SLOFS *fsp);
extern char *slofs_getcwd(SLOFS *fsp);
extern int slofs_setcwd(SLOFS *fsp, const char *path);

extern SLOFS_FILE *slofs_open(SLOFS *fsp, const char *filename, const char *mode);
extern int slofs_stat(SLOFS *fsp, const char *filename, struct slofs_stat *buf);
extern int slofs_read(SLOFS_FILE *fp, char *buffer, long max);
extern int slofs_write(SLOFS_FILE *fp, char *buffer, long length);
extern int slofs_unlink(SLOFS *fsp, const char *filename);
extern int slofs_rename(SLOFS *fsp, const char *oldname, const char *newname);
extern int slofs_seek(SLOFS_FILE *fp, enum slofs_seek_whence whence, long loc);
extern int slofs_tell(SLOFS_FILE *fp);
extern int slofs_close(SLOFS_FILE *fp);

extern SLOFS_DIR *slofs_opendir(SLOFS *fsp, const char *filename);
extern const char *slofs_readdir(SLOFS_DIR *dp);
extern void slofs_seekdir(SLOFS_DIR *dp, long loc);
extern int slofs_rewinddir(SLOFS_DIR *dp);
extern long slofs_telldir(SLOFS_DIR *dp);
extern int slofs_closedir(SLOFS_DIR *dp);

#endif
