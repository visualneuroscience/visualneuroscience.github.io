# TODO list and guidelines for people who are leaving
- [ ] Make sure that all subject's private data that is irrelevant for research (e.g. bank account information for reimbursement) is deleted
- [ ] Make sure that all incidental findings have been clarified, and once this is the case, delete subjects' contact information if you kept it
- [ ] Return your key to Chrissy once you don't need a desk
- [ ] At the top level of your directory on storage, create a text/markdown named file named "projects" containing server paths (/storage/,   J:\, or external storage in the case of Marilena) as follows
- [ ] It would be nice if you could put a contact email for after your uni-graz email address expires (optional, of course) at the top
1. project nickname
2. Final version (from the MRI/behavioral lab) of the stimulus script
3. Raw data (whichever applies)
	a. behavioral
	b. eyetracking
	c. physiology
	d. (f)MRI
	e. pdf of the MRI protocol
4. Subject-level analysis scripts (including preprocessing)
5. Subject-level results
6. Group analysis scripts
7. Group results
8. Latest version of the submitted manuscript with rebuttal, if applicable
9. Posters and submitted conference abstracts related to the study
10. Location of the consent forms (either electronic or paper)

# Example: 
``/storage/natalia/projects.md``

## Fast and functionally specific cortical thickness changes induced by visual stimulation
1. project nickname: hexcite
2. stimulus script: #todo 
3. Raw data
	-  bahavior: ``/storage/nv_shared/projects/excitex/matfiles/``
	-  MRI: ``/storage/nv_shared/projects/excitex/bids/``
	-  PDF of the MRI protocol: ``/storage/nv_shared/projects/excitex/111_NZ03_excite_autoalign.pdf``
	
4. First level analysis scripts (including preprocessing): ``/storage/natalia/projects/hexcite/analyze_hexcite_struc_R1.sh``, ``/storage/natalia/projects/hexcite/analyze_hexcite_fmri.sh``
5. Subject-level results ``/storage/natalia/projects/hexcite/bids/derivatives/``
6. Group analysis scripts ``/storage/natalia/projects/hexcite/bids/code/analyze_hexcite_final.m``
7. Group results: ``/storage/natalia/projects/hexcite/group_lowres/``
8. Latest version of the submitted manuscript with rebuttal: ``/storage/natalia/projects/hexcite/manuscript/hexcite_CerCor_R1``
9. Posters and submitted conference abstracts related to the study ``/storage/natalia/projects/hexcite/presentations``
10. Paper - Corner office, rightmost drawer
