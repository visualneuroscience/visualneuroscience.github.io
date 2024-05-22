Information about MRI and fMRI, processing and analysis steps.



Topics:

# BIDS

Brain Imaging Data Structure (more information [here](https://bids-standard.github.io/bids-starter-kit/)).

## Validating BIDS dataset

With docker, you can run this line in the terminal:

`$ docker run -ti --rm -v [path_to_your_toplevel_bids_directory]:/data:ro bids/validator /data`


Common issues:

- files don't follow BIDS naming conventions (more info about filenames [here](https://bids-standard.github.io/bids-starter-kit/folders_and_files/files.html))
- events.tsv files are missing
- participants.tsv is missing
- participants.json file is missing or does not describe all variables from the tsv file
- datasset_description is missing or there is no name of the dataset or author names in it.
- readme file is missing or too short
- ...


# OSF

Upload your dataset to OSF using *osfclient* (user's guide [here](https://osfclient.readthedocs.io/en/latest/cli-usage.html)).
This is a useful python-based package to uploading data in bulk to OSF, especially because you cannot upload folders to OSF projects via browser.

Installation:
`$ pip3 install osfclient`

### Upload a file to an OSF project
`$ osf -p <projectid> -u yourOSFacount@example.com upload local/file.txt remote/path.txt`
### Upload a folder (recursively) to an OSF project
`$ osf -p <projectid> -u yourOSFacount@example.com upload -r local/folder remote/path`

### Set your OSF acctount password
Set a password so you don't have to enter it each time you upload data

`$ export OSF_PASSWORD=yourpassword`
