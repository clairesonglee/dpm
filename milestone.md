# Darshan-PNetCDF Module 
This repo supports the parallel I/O library PNetCDF within the Darshan HPC characterization tool. Each function call implemented will be accompanied by testcode (located in the testcode folder) and an output file (located in the dxt-parser folder). The progress of the module is tracked through milestones. 

## Milestones 
* Blocking Function APIs
  * Independent Functions
	* ncmpi_put_var*
		* Source file: 
		* Testfile: 
		* Output file: 

	* ncmpi_get_var*
		* Source file: 
		* Testfile: 
		* Output file: 

  * Collective Functions 
	* ncmpi_put_var*_all
		* Source file: 
		* Testfile: 
		* Output file: 
	
	* ncmpi_get_var*_all
		* Source file: 
		* Testfile: 
		* Output file: 

* Non-blocking Function APIs
  * Independent Functions 
  	* ncmpi_iput_var*
		* Source file: 
		* Testfile: 
		* Output file: 

	* ncmpi_iget_var*
		* Source file: 
		* Testfile: 
		* Output file: 

	* ncmpi_bput_var*
		* Source file: 
		* Testfile: 
		* Output file: 

  * Collective Functions 
	* ncmpi_iput_var*_all
		* Source file: 
		* Testfile: 
		* Output file: 

	* ncmpi_iget_var*
		* Source file: 
		* Testfile: 
		* Output file: 

	* ncmpi_bput_var*
		* Source file: 
		* Testfile: 
		* Output file: 

* Wait Function for Non-blocking APIs
  * Independent Function 
	* ncmpi_wait
		* Source file: 
		* Testfile: 
		* Output file: 

  * Collective Function
	* ncmpi_wait_all
		* Source file: 
		* Testfile: 
		* Output file: 
