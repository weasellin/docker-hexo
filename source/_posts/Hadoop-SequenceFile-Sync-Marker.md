---
title: Hadoop SequenceFile Sync Marker
date: 2019-11-12 00:33:21
tags:
---

From Hadoop [wiki](https://cwiki.apache.org/confluence/display/HADOOP2/SequenceFile),

> The sync marker permits seeking to a random point in a file and then re-synchronizing input with record boundaries. This is required to be able to efficiently split large files for MapReduce processing.

But what it actually marks? And how it could be used in "seeking"?

Here is my starting investigation.

The code piece for sync marker generation.

```java
public static class Writer implements java.io.Closeable, Syncable {
  ...
    MessageDigest digester = MessageDigest.getInstance("MD5");
    long time = Time.now();
    digester.update((new UID()+"@"+time).getBytes(StandardCharsets.UTF_8));
    sync = digester.digest();
  ...
```
[code](https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java#L869)

and the piece for insertion.


```java
    public void sync() throws IOException {
      if (sync != null && lastSyncPos != out.getPos()) {
        out.writeInt(SYNC_ESCAPE);                // mark the start of the sync
        out.write(sync);                          // write sync
        lastSyncPos = out.getPos();               // update lastSyncPos
      }
    }
```
[code](https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java#L1338)

From these codes, the sync marker seems just being generated in the "Writer" initialization once, and write into the file header and the output while the output buffer full over a certain size.

- In `Writer` & `RecordCompressWriter`: refer to the `SYNC_INTERVAL`
  - refer to this [commit](https://github.com/apache/hadoop/commit/07825f2b49384dbec92bfae87ea661cef9ffab49), it has been changed from `100 * SYNC_SIZE` to `5 * 1024 * SYNC_SIZE`
- In `BlobkCompressWriter`:  refer to `IO_SEQFILE_COMPRESS_BLOCKSIZE_KEY/DEFAULT` (default: 1,000,000)

```Java
/**
 * @see
 * <a href="{@docRoot}/../hadoop-project-dist/hadoop-common/core-default.xml">
 * core-default.xml</a>
 */
public static final String  IO_SEQFILE_COMPRESS_BLOCKSIZE_KEY =
  "io.seqfile.compress.blocksize";
/** Default value for IO_SEQFILE_COMPRESS_BLOCKSIZE_KEY */
public static final int     IO_SEQFILE_COMPRESS_BLOCKSIZE_DEFAULT = 1000000;
```
[code](https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/fs/CommonConfigurationKeysPublic.java#L227)

```Java
/**
 * The number of bytes between sync points. 100 KB, default.
 * Computed as 5 KB * 20 = 100 KB
 */
public static final int SYNC_INTERVAL = 5 * 1024 * SYNC_SIZE; // 5KB*(16+4)
```
[code](https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java#L218)

Then, in the reading part, the sync marker will be read in the `Reader` `init`.

[code](https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java#L2029)

```java
/** Seek to the next sync mark past a given position.*/
public synchronized void sync(long position) throws IOException {
  if (position+SYNC_SIZE >= end) {
    seek(end);
    return;
  }

  if (position < headerEnd) {
    // seek directly to first record
    in.seek(headerEnd);
    // note the sync marker "seen" in the header
    syncSeen = true;
    return;
  }

  try {
    seek(position+4);                         // skip escape
    in.readFully(syncCheck);
    int syncLen = sync.length;
    for (int i = 0; in.getPos() < end; i++) {
      int j = 0;
      for (; j < syncLen; j++) {
        if (sync[j] != syncCheck[(i+j)%syncLen])
          break;
      }
      if (j == syncLen) {
        in.seek(in.getPos() - SYNC_SIZE);     // position before sync
        return;
      }
      syncCheck[i%syncLen] = in.readByte();
    }
  } catch (ChecksumException e) {             // checksum failure
    handleChecksumException(e);
  }
}
```
[code](https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java#L2726)


## Conclusion

- This sync marker allows the seeking operation to **align** to records or blocks boundary.
- But it relies on an existing seeking operation, which is implemented in `Seekable.seek()`.
- Next question, "How is the seek implemented among a distributed file".

## References

- https://hadoop.apache.org/docs/r2.8.0/api/org/apache/hadoop/io/SequenceFile.html
- https://www.reddit.com/r/hadoop/comments/4negaa/what_is_the_sequence_file_sync_marker_how_does_it/
- https://github.com/apache/hadoop/blob/release-3.2.0-RC1/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java
- https://github.com/apache/hadoop/blob/release-2.8.0-RC3/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/io/SequenceFile.java
