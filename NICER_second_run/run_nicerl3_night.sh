																																																																																																										#!/bin/bash
## Automatically detect obsIDs in the output folder and run nicerl3-lc with day settings.

# Define base directory for output
output_base="output"

# Loop through all obsID folders in the output directory
for obsid_base in "$output_base"/[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9];
do
    # Extract the obsID from the folder name
    obsid=$(basename "$obsid_base")
    
    # Define the input directory where the barycorr-corrected .evt file is stored
    input_dir="$output_base/$obsid"
    
    # Define the barycorr-corrected .evt file as input for nicerl3-lc
    clfile="$input_dir/ni${obsid}_0mpu7_cl_night.evt"
    
    # Check if the barycorr-corrected file exists before proceeding
    if [ -f "$clfile" ]; then
        # Run the nicerl3-lc command with the detected input
        nicerl3-lc indir="$input_dir" \
                   clfile="$clfile" \
                   chatter=2 pirange=80-1100 \
                   clobber=yes timebin=0.01 \
                   suffix=_night_0.1 \
                   2>&1 | tee "$input_dir/${obsid}_night_lc.log"
        
        echo "Processed light curve for $obsid"
    else
        echo "file not found for $obsid. Skipping..."
    fi
done
