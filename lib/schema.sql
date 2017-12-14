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

/***********************************************************************/
/* Schema **************************************************************/
/***********************************************************************/

/* Clean up any previous runs */
DROP TABLE IF EXISTS files;
DROP TABLE IF EXISTS dirs;

/*
 * Create the files and dirs schemas, and their respective indexes.
 */
CREATE TABLE files (
  id integer not null primary key autoincrement,
  dir_id integer not null,
  name text not null,
  data text not null,
  ctime timestamp not null default current_timestamp,
  mtime timestamp not null default current_timestamp
);

CREATE TABLE dirs (
  id integer not null primary key autoincrement,
  parent_id integer,
  name text not null,
  ctime timestamp not null default current_timestamp,
  mtime timestamp not null default current_timestamp
);

CREATE TABLE metadata (
  version_major integer,
  version_minor integer,
  version_teeny integer,
  label text
);

CREATE UNIQUE INDEX dir_name_parent_idx ON dirs (name, parent_id);
CREATE UNIQUE INDEX dir_name_dir_id_idx ON files (name, dir_id);

/***********************************************************************/
/* Files ***************************************************************/
/***********************************************************************/

/*
 * Enforce POSIX restrictions on naming of files. Filenames may not
 *   - Be empty.
 *   - Conflict with existing filenames in the same dir.
 *   - Conflict with existing directories in the same dir.
 * On proper insert, update the directory's mtime.
 */
CREATE TRIGGER file_create_trigger
BEFORE INSERT ON files
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'name may not be empty')   /* empty case */
           WHERE new.name = '';

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on dirs */
           WHERE (SELECT COUNT(name) FROM dirs
                         WHERE parent_id = new.dir_id
                         AND name = new.name) != 0;

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on files */
           WHERE (SELECT COUNT(name) FROM files
                  WHERE dir_id = new.dir_id
                  AND name = new.name) != 0;

    UPDATE dirs SET mtime = CURRENT_TIME WHERE dirs.id = new.dir_id;
END;

/*
 * Enforce POSIX restrictions on naming of files. Filenames may not
 *   - Be empty.
 *   - Conflict with existing filenames in the destination dir.
 *   - Conflict with existing directories in the destination dir.
 * On proper update, update the directory's mtime.
 */
CREATE TRIGGER file_rename_trigger
BEFORE UPDATE OF name, dir_id ON files
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'name may not be empty')   /* empty case */
           WHERE new.name = '';

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on dirs */
           WHERE (SELECT COUNT(name) FROM dirs
                  WHERE parent_id = new.dir_id
                  AND name = new.name) != 0;

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on files */
           WHERE (SELECT COUNT(name) FROM files
                  WHERE dir_id = new.dir_id
                  AND name = new.name) != 0;

    UPDATE dirs SET mtime = CURRENT_TIME WHERE dirs.id = new.dir_id;
END;

/*
 * Enforce POSIX semantics that the mtime of the directory containing
 * a just-modified file and the file are updated on each write.
 */
CREATE TRIGGER file_write_trigger
BEFORE UPDATE ON files
FOR EACH ROW BEGIN
    UPDATE dirs SET mtime = CURRENT_TIME WHERE dirs.id = old.dir_id;
    UPDATE files SET mtime = CURRENT_TIME WHERE files.id = old.id;
END;

/*
 * Enforce POSIX semantics that the mtime of the directory containing a file is
 * updated when the file is removed.
 */
CREATE TRIGGER file_unlink_trigger
AFTER DELETE ON files
FOR EACH ROW BEGIN
    UPDATE dirs SET mtime = CURRENT_TIME WHERE dirs.id = old.dir_id;
END;


/***********************************************************************/
/* Directories *********************************************************/
/***********************************************************************/

/*
 * Enforce POSIX restrictions on naming of directories. Names may not
 *   - Be empty (aside from the root dir, which is id 0 and empty name).
 *   - Conflict with existing filenames in the same dir.
 *   - Conflict with existing directories in the same dir.
 */
CREATE TRIGGER dir_create_trigger
BEFORE INSERT on dirs
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'name may not be empty')   /* empty case */
           WHERE (SELECT COUNT(name) FROM dirs WHERE name = '') = 1
           AND new.name = '';

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on dirs */
           WHERE (SELECT COUNT(name) FROM dirs
                         WHERE id = new.parent_id
                         AND name = new.name) != 0;

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on files */
           WHERE (SELECT COUNT(name) FROM files
                         WHERE dir_id = new.parent_id
                         AND name = new.name) != 0;

    UPDATE dirs SET mtime = CURRENT_TIME WHERE dirs.id = new.parent_id;
END;

/*
 * Enforce POSIX restrictions on naming of files. Dirnames may not
 *   - Be empty (aside from the root dir).
 *   - Conflict with existing filenames in the destination dir.
 *   - Conflict with existing directories in the destination dir.
 */
CREATE TRIGGER dir_rename_trigger
BEFORE INSERT ON dirs
FOR EACH ROW BEGIN
    SELECT RAISE(ROLLBACK, 'name may not be empty')   /* empty case */
           WHERE (SELECT COUNT(name) FROM dirs WHERE name = '') = 1
           AND new.name = '';

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on dirs */
           WHERE (SELECT COUNT(name) FROM dirs
                  WHERE parent_id = new.parent_id
                  AND name = new.name) != 0;

    SELECT RAISE(ROLLBACK, 'name is not unique')      /* unique check on files */
           WHERE (SELECT COUNT(name) FROM files
                  WHERE dir_id = new.parent_id
                  AND name = new.name) != 0;

    UPDATE dirs SET mtime = CURRENT_TIME WHERE dirs.id = new.id;
END;

/*
 * Enforce filesystem semantics that make sure that no files may be
 * orphaned when their containing directory is unlinked.
 */
CREATE TRIGGER dir_unlink_trigger
AFTER DELETE ON dirs
FOR EACH ROW BEGIN
    DELETE FROM files WHERE dir_id = old.id;
END;

/***********************************************************************/
/* Initial Data ********************************************************/
/***********************************************************************/

INSERT INTO dirs (id, parent_id, name) VALUES (0, 0, '');
INSERT INTO metadata VALUES (0, 0, 1, NULL);
