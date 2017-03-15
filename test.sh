#!/bin/bash
#
# Stress-test a Pachyderm cluster in various ways with some multi-GB files.

# Standard paranoid.
set -euo pipefail

#echo "=== Deleting all pachyderm state"
#pachctl delete-all

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

wait_for_commit() {
	echo "VERIFYING: Waiting for commit finished on $1"
	while true; do
		if pachctl inspect-commit $1 master | grep Finished; then
			break;
		fi
		sleep 3
	done
	echo "Found it!"
}

test_1() {
    echo "=== Test 1: Add 33 GB file using S3 URL"

    set -o xtrace
    pachctl create-repo eubookshop_s3
	pachctl start-commit eubookshop_s3 master
    pachctl put-file eubookshop_s3 master EUbookshop0.2.tar.gz \
        -f s3://fdy-pachyderm-public-test-data/opus/EUbookshop0.2.tar.gz
	pachctl finish-commit eubookshop_s3 master
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

flat_put() {
	echo "=== carefully putting $1 into $2"

	cat $1 | while read line; do \
		echo "		--- uploading $line"
		pachctl put-file $2 master /`basename $line` -f $line; \
	done
}


test_3() {
	test_3_from_file URLS.txt
}

test_3_from_file() {
    echo "=== Test 3: Add 60 GB of files"

    set -o xtrace
    pachctl create-repo opus_tars_$1
    pachctl start-commit opus_tars_$1 master
	flat_put URLS-$1.txt opus_tars_$1
    pachctl finish-commit opus_tars_$1 master
    set +o xtrace

#    wait_for_pfs_glob "opus_tars_$1/master/EUbookshop0.2.tar.gz"
	wait_for_commit opus_tars_$1
}

# You can run this instead of test_3 in order to debug the pipelines before
# trying it with the real test_3.
fake_test_3() {
    echo "=== Faking test 3 with a much smaller amount of data for debugging"

    set -o xtrace
    pachctl create-repo opus_tars
	pachctl start-commit opus_tars master
    #pachctl put-file opus_tars master -c -i SMALL-URLS.txt
	flat_put SMALL-URLS.txt opus_tars
	pachctl finish-commit opus_tars master
    set +o xtrace
}

# This depends on the opus_tars repo from test_3 (or fake_test_3).
test_4() {
    echo "=== Test 4: Copy large files from input to output in FILE mode"

    set -o xtrace
	sed -e 's/opus_copy/opus_copy_'"$1"'/g' copy-pipeline.json > copy.json
	sed -ie 's/opus_tars/opus_tars_'"$1"'/g' copy.json
    pachctl create-pipeline -f copy.json
    set +o xtrace

    wait_for_pfs_glob "opus_copy_$1/*/EUconst0.1.tar.gz"
}

# This depends on the opus_tars repo from test_3 (or fake_test_3).
test_5() {
    echo "=== Test 5"

    set -o xtrace
	sed -e 's/opus_unpack/opus_unpack_'"$1"'/g' unpack-pipeline.json > unpack.json
	sed -ie 's/opus_copy/opus_copy_'"$1"'/g' unpack.json
    pachctl create-pipeline -f unpack.json
	sed -e 's/opus_repack/opus_repack_'"$1"'/g' repack-pipeline.json > repack.json
	sed -ie 's/opus_unpack/opus_unpack_'"$1"'/g' repack.json
    pachctl create-pipeline -f repack.json
    set +o xtrace

    wait_for_pfs_glob "opus_repack_$1/*/en.tar"
}

# The basic tests of file addition.
#test_1
#test_2

# You need one of the other of these (but not both) for test_4 and test_5.
#test_3
#fake_test_3
#ADDRESS=52.91.245.49:30650
#ADDRESS=54.175.9.150:30650
# restarted instances / new ip
ADDRESS=52.200.153.133:30650
dataset=4

pachctl delete-pipeline opus_repack_$dataset
pachctl delete-repo opus_repack_$dataset
pachctl delete-pipeline opus_unpack_$dataset
pachctl delete-repo opus_unpack_$dataset
pachctl delete-pipeline opus_copy_$dataset
pachctl delete-repo opus_copy_$dataset
pachctl delete-repo opus_tars_$dataset

echo "Inputting data - starting at"
date
test_3_from_file $dataset
echo "Finished inputting data at:"
date

# Pipeline tests.
echo "Starting copy at"
date
test_4 $dataset
echo "Finished copy at"
date
test_5 $dataset
echo "Finished un/repack at:"
date

