# Darshan-PNetCDF Module 
This repo supports the parallel I/O library PNetCDF within the Darshan HPC characterization tool. Each function call implemented will be accompanied by testcode (located in the testcode folder) and an output file (located in the dxt-parser folder). The progress of the module is tracked through milestones. 

## Source files
* darshan-pnetcdf-getput.m4
	* darshan-pnetcdf-getput.h
* darshan-pnetcdf-forward-decl-getput.m4
	* darshan-pnecdf-forward-decl-getput.h 
* darshan-pnetcdf-stubs-getput.m4
	* darshan-pnecdf-stubs-getput.h 
* getput-utils.m4

## Milestones 
* Blocking Function APIs
  * Independent Functions
	* ncmpi_put_var(1,a,s,m)
		* Testfile: getput_var.c 
		* Output file: getput_var.txt 

	* ncmpi_put_varn
		* Testfile: 
		* Output file: getput_var.txt

	* ncmpi_put_vard
		* Testfile: 
		* Output file: getput_var.txt

	* ncmpi_get_var(1,a,s,m)
		* Testfile: getput_var.c 
		* Output file: getput_var.txt

	* ncmpi_get_varn
		* Testfile: 
		* Output file: getput_var.txt

	* ncmpi_get_vard
		* Testfile: 
		* Output file: getput_var.txt

  * Collective Functions 
	* ncmpi_put_var*_all
		* Testfile: getput_var_all.c 
		* Output file: getput_var.txt
	
	* ncmpi_get_var*_all
		* Testfile: getput_var_all.c
		* Output file: getput_var.txt

* Non-blocking Function APIs
  * Independent Functions 
  	* ncmpi_iput_var*
		* Testfile: 
		* Output file: 

	* ncmpi_iget_var*
		* Testfile: 
		* Output file: 

	* ncmpi_bput_var*
		* Testfile: 
		* Output file: 

  * Collective Functions 
	* ncmpi_iput_var*_all
		* Testfile: 
		* Output file: 

	* ncmpi_iget_var*_all
		* Testfile: 
		* Output file: 

	* ncmpi_bput_var*
		* Testfile: 
		* Output file: 

* Wait Function for Non-blocking APIs
  * Independent Function 
	* ncmpi_wait
		* Testfile: 
		* Output file: 

  * Collective Function
	* ncmpi_wait_all
		* Testfile: 
		* Output file: 

* Basic Function APIs
  * Open Function
	* ncmpi_open
  * Close Function
	* ncmpi_close
  * Redef Function
	* ncmpi_redef
  * Enddef Function
	* ncmpi_enddef
  * Sync Function
	* ncmpi_sync
