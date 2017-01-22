#!/bin/bash
#
# Stress-test a Pachyderm cluster in various ways with some multi-GB files.

# Standard paranoid.
set -euo pipefail

echo "=== Deleting all pachyderm state"
pachctl delete-all

# Wait for a file in ~/pfs matching the glob specified in $1.
wait_for_pfs_glob() {
    local wanted="$1"
    echo "VERIFYING: Waiting for data at $HOME/pfs/$1"
    while true; do
        if compgen -G "$HOME/pfs/$1" > /dev/null; then
            break
        fi
        sleep 3
    done
    echo "Found it!"
}

test_1() {
    echo "=== Test 1: Add 33 GB file using S3 URL"

    set -o xtrace
    pachctl create-repo eubookshop_s3
    pachctl put-file eubookshop_s3 master EUbookshop0.2.tar.gz -c \
        -f s3://fdy-pachyderm-public-test-data/opus/EUbookshop0.2.tar.gz
    set +o xtrace

    wait_for_pfs_glob "eubookshop_s3/master/EUbookshop0.2.tar.gz"
}

test_2() {
    echo "=== Test 2: Add 33 GB file using HTTP URL"

    set -o xtrace
    pachctl create-repo eubookshop_http
    pachctl put-file eubookshop_http master EUbookshop0.2.tar.gz -c \
        -f https://fdy-pachyderm-public-test-data.s3.amazonaws.com/opus/EUbookshop0.2.tar.gz
    set +o xtrace

    wait_for_pfs_glob "eubookshop_http/master/EUbookshop0.2.tar.gz"
}

test_3() {
    echo "=== Test 3: Add 60 GB of files"

    set -o xtrace
    pachctl create-repo opus_tars
    pachctl put-file opus_tars master -c -i URLS.txt
    set +o xtrace

    wait_for_pfs_glob "opus_tars/master/EUbookshop0.2.tar.gz"
}

# You can run this instead of test_3 in order to debug the pipelines before
# trying it with the real test_3.
fake_test_3() {
    echo "=== Faking test 3 with a much smaller amount of data for debugging"

    set -o xtrace
    pachctl create-repo opus_tars
    pachctl put-file opus_tars master EUconst0.1.tar.gz -c \
        -f https://fdy-pachyderm-public-test-data.s3.amazonaws.com/opus/EUconst0.1.tar.gz
    set +o xtrace
}

# This depends on the opus_tars repo from test_3 (or fake_test_3).
test_4() {
    echo "=== Test 4: Copy large files from input to output in FILE mode"

    set -o xtrace
    pachctl create-pipeline -f copy-pipeline.json
    set +o xtrace

    wait_for_pfs_glob "opus_copy/*/EUconst0.1.tar.gz"
}

# This depends on the opus_tars repo from test_3 (or fake_test_3).
test_5() {
    echo "=== Test 5"

    set -o xtrace
    pachctl create-pipeline -f unpack-pipeline.json
    pachctl create-pipeline -f repack-pipeline.json
    set +o xtrace

    wait_for_pfs_glob "opus_repack/*/en.tar"
}

# The basic tests of file addition.
test_1
test_2

# You need one of the other of these (but not both) for test_4 and test_5.
test_3
#fake_test_3

# Pipeline tests.
test_4
test_5

