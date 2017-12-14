## What is SloFS?
SloFS (pronounced slow-FS) is a filesystem built entirely upon
sqlite3. The purpose is to provide a single-file blob of data storage
to applications that need it. Additionally, the second goal was to
have a standard set of open tools with which to re-read the data back
out with. As such, SloFS includes a set of commandline tools much like
the existing POSIX ones (ls, mkdir, cat, rm, etc.) to make examining
the data store easy.

## Why?
Why not? During development of the pm password management tool, the authors
found it necessary to have an open format, easy to read data file. Originally
YAML was chosen for its terse and easy to write and debug data format --
unfortunately, the C libraries for parsing such a data structure are too
painful. After considering other options, they finally came across zziplib.
Realizing that their data format was just a simple set of strings and that
reading and writing to a filesystem were simple and well-defined algorithms
already, the authors set out to start using this library instead. Unfortunately,
they realized that zziplib is a read only API to zip files, and finally came up
with the crazy idea of implementing a complete filesystem on top of a very
lightweight SQL database. SloFS was the result of their discussion and research.

SloFS -- It's not stupid, it's just slow.

