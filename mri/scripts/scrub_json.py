""" 
This script loops through a BIDS dataset and deletes sensitive information from JSON files.
This script does NOT check for header info in the nifti files.
Original JSON files will be overwritten.

How to run:
./scrub_json.py [path_to_bids_directory]

AA 10/23
"""

# dependencies
import os
import sys
import json

#  bids folder to scrub
if len(sys.argv) < 2:
    print("Enter bids directory path to scrub")
    sys.exit()
elif len(sys.argv) > 2:
    print("Enter only bids directory path to scrub")
    sys.exit()
else:
    if not os.path.exists(sys.argv[1]):
        print("Directory does not exist")
        sys.exit()
    else:
        bids_dir = sys.argv[1]


# which keys are checked
sens_info = ['InstitutionName', 'InstitutionAddress', 'DeviceSerialNumber', 'StationName', 'ProcedureStepDescription', 'AcquisitionTime']
# key scrubber
def json_key_scrub(file):
    for key, value in file.items():
        if key in sens_info:
            # replacement string
            file[key] = "deleted"
    return file

# iterate through all jsons in bids folder
for sub in os.listdir(bids_dir):
    if sub.startswith("sub-"):
        for ses in os.listdir(os.path.join(bids_dir,sub)):
            for acq in os.listdir(os.path.join(bids_dir,sub, ses)):
                for acq_file in os.listdir(os.path.join(bids_dir,sub, ses, acq)):
                    if acq_file.endswith(".json"):
                        print(acq_file)
                        json_fpath = os.path.join(bids_dir,sub, ses, acq, acq_file)
                        json_anon = json_key_scrub(json.load(open(json_fpath)))                        
                        # overwrite new JSON
                        with open(json_fpath, "w") as fpath:
                            json.dump(json_anon, fpath, indent=4)
