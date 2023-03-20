#!/bin/sh

# Check if both arguments were provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 filesdir searchstr"
  exit 1
fi
# Assign arguments to variables
filesdir=$1
searchstr=$2

# Check if filesdir exists and is a directory
if [ ! -d "$filesdir" ]; then
  echo "Error: $filesdir is not a directory"
  exit 1
fi

# Use find and grep to count the number of files and matching lines
num_files=$(find "$filesdir" -type f | wc -l)
num_matches=$(find "$filesdir" -type f -exec grep -H "$searchstr" {} \; | wc -l)

# Print results
echo "The number of files are $num_files and the number of matching lines are $num_matches"
