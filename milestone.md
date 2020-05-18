# Darshan-PNetCDF Module 
This repo supports the parallel I/O library PNetCDF within the Darshan HPC characterization tool. Each function call implemented will be accompanied by testcode (located in the testcode folder) and an output file (located in the dxt-parser folder). The progress of the module is tracked through milestones. 

## Source files
* darshan-pnetcdf-getput.m4
	* darshan-pnetcdf-getput.h
* darshan-pnetcdf-forward-decl-getput.m4
	* darshan=pnecdf-forward-decl-getput.h 
* darshan-pnetcdf-stubs-getput.m4
	* darshan=pnecdf-stubs-getput.h 
* getput-utils.m4

## Milestones 
* Blocking Function APIs
  * Independent Functions
	* ncmpi_put_var*
		* Testfile: getput_var.c 
		* Output file: 

	* ncmpi_get_var*
		* Testfile: getput_var.c 
		* Output file: 

  * Collective Functions 
	* ncmpi_put_var*_all
		* Testfile: getput_var_all.c 
		* Output file: 
	
	* ncmpi_get_var*_all
		* Testfile: getput_var_all.c
		* Output file: 

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

	* ncmpi_iget_var*
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
