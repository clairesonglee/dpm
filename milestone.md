# Darshan-PNetCDF Module 
This repo supports the parallel I/O library PNetCDF within the Darshan HPC characterization tool. Each function call implemented will be accompanied by testcode (located in the testcode folder) and an output file (located in the dxt-parser folder). The progress of the module is tracked through milestones. 

## Milestones 
* Blocking Function APIs
  * Independent Functions
	* ncmpi_put_var*
		* ncmpi_put_var_(type)
		* ncmpi_put_var1_(type)
		* ncmpi_put_vara_(type)
		* ncmpi_put_vars_(type)
		* ncmpi_put_varm_(type)
		* ncmpi_put_varn_(type)
		* ncmpi_put_vard

	* ncmpi_get_var*
		* ncmpi_get_var_(type)
		* ncmpi_get_var1_(type)
		* ncmpi_get_vara_(type)
		* ncmpi_get_vars_(type)
		* ncmpi_get_varm_(type)
		* ncmpi_get_varn_(type)
		* ncmpi_get_vard

  * Collective Functions 
	* ncmpi_put_var*_all
		* ncmpi_put_var_(type)_all
		* ncmpi_put_var1_(type)_all
		* ncmpi_put_vara_(type)_all
		* ncmpi_put_vars_(type)_all
		* ncmpi_put_varm_(type)_all
		* ncmpi_put_varn_(type)_all
		* ncmpi_put_vard_all

	* ncmpi_get_var*_all
		* ncmpi_get_var_(type)_all
		* ncmpi_get_var1_(type)_all
		* ncmpi_get_vara_(type)_all
		* ncmpi_get_vars_(type)_all
		* ncmpi_get_varm_(type)_all
		* ncmpi_get_varn_(type)_all
		* ncmpi_get_vard_all

* Non-blocking Function APIs
  * Independent Functions 
  	* ncmpi_iput_var*
		* ncmpi_iput_var(kind)_(type)
		* ncmpi_iput_varn_(type)

    	* ncmpi_iget_var*
		* ncmpi_iget_var(kind)_(type)
		* ncmpi_iget_varn_(type)

    	* ncmpi_bput_var*
		* ncmpi_bput_var(kind)_(type)
		* ncmpi_bput_varn_(type)

  * Collective Functions 
	* ncmpi_iput_var*_all
		* ncmpi_iput_var(kind)_(type)_all
		* ncmpi_iput_varn_(type)_all

	* ncmpi_iget_var*
		* ncmpi_iget_var(kind)_(type)_all
		* ncmpi_iget_varn_(type)_all

	* ncmpi_bput_var*
		* ncmpi_bput_var(kind)_(type)_all
		* ncmpi_bput_varn_(type)_all

* Wait Function for Non-blocking APIs
  * Independent Function 
	* ncmpi_wait

  * Collective Function
	* ncmpi_wait_all
