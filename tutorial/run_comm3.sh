#!/usr/bin/bash

HEALPIX_ROOT=
COMM3_BIN=
PARAM_FILE=param_BP_v8.00_full.txt
CHAINS_DIR=chains
OUT_FILE=slurm.txt
NUM_PROC=64

export HEALPIX=$HEALPIX_ROOT
mpirun -np $NUM_PROC $COMM3_BIN $PARAM_FILE 2>&1 | tee $CHAINS_DIR/$OUT_FILE
