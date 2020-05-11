# Darshan-PNetCDF Module 
This repo supports the parallel I/O library PNetCDF within the Darshan HPC characterization tool. Each function call implemented will be accompanied by testcode (located in the testcode folder) and an output file (located in the dxt-parser folder). The progress of the module is tracked through milestones. 

## Milestones 
* Blocking Function APIs

  * ncmpi_put_var*
	* ncmpi_put_var_<type>
	* ncmpi_put_var1_<type>
	* ncmpi_put_vara_<type>
	* ncmpi_put_vars_<type>
	* ncmpi_put_varm_<type>
	* ncmpi_put_varn_<type>
	* ncmpi_put_vard

  * ncmpi_get_var*
	* ncmpi_get_var_<type>
	* ncmpi_get_var1_<type>
	* ncmpi_get_vara_<type>
	* ncmpi_get_vars_<type>
	* ncmpi_get_varm_<type>
	* ncmpi_get_varn_<type>
	* ncmpi_get_vard


* Non-blocking Function APIs

  * ncmpi_iput_var*
	* ncmpi_iput_var<kind>_<type>
	* ncmpi_iput_varn_<type>

  * ncmpi_iget_var*
	* ncmpi_iget_var<kind>_<type>
	* ncmpi_iget_varn_<type>

  * ncmpi_bput_var*
	* ncmpi_bput_var<kind>_<type>
	* ncmpi_bput_varn_<type>


* Wait Function for Non-blocking APIs
 
  * ncmpi_wait

  * ncmpi_wait_all
