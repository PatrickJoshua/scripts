#!/bin/bash
# Purge RAM Cache (equivalent to macOS purge)
# Flushes dirty pages to disk first and then releases pagecache, dentries, and inodes.

echo "Synchronizing cached writes to disk..."
sync

echo "Clearing pagecache, dentries, and inodes..."
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null

echo "RAM Cache cleared successfully."
