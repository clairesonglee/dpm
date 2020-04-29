#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>
    
int main (void) {

	MPI_Init(NULL, NULL);
 
	int err, ncid, varid, cmode = NC_CLOBBER | NC_64BIT_DATA;
	MPI_Info info;
    
	MPI_Info_create (&info);
	MPI_Info_set (info, "romio_no_indep_rw", "true");
	MPI_Info_set (info, "nc_header_read_chunk_size", "1024");

	err = ncmpi_create(MPI_COMM_WORLD, "test_getput.nc", cmode, info, &ncid); 
	if(err != NC_NOERR) printf("Error: %s\n", ncmpi_strerror(err));

	double var; /* initialize temporary variable */
	err = ncmpi_inq_varid(ncid, "d", &varid);
	if(err != NC_NOERR) printf("ncmpi_inq_varid: %s\n", ncmpi_strerror(err)); 
	var = 1.0;

	err = ncmpi_enddef(ncid); 
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	/* independently write single data value to file */
	err = ncmpi_begin_indep_data(ncid);
	err = ncmpi_put_var1_double(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_put_var1_double: %s\n", ncmpi_strerror(err));
	err = ncmpi_end_indep_data(ncid);

	/* collectively write single data value to file */
	err = ncmpi_put_var1_double_all(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_put_var1_double_all: %s\n", ncmpi_strerror(err));

	/* independently read single data value from file */
	err = ncmpi_begin_indep_data(ncid);
	err = ncmpi_get_var1_double(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_get_var1_double: %s\n", ncmpi_strerror(err));
	if (var != 1.0) printf("ncmpi_get_var1_double: unexpected value"); 
	err = ncmpi_end_indep_data(ncid);

	/* collectively read single data value from file */
	err = ncmpi_get_var1_double_all(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_get_var1_double_all: %s\n", ncmpi_strerror(err));
	if (var != 1.0) printf("ncmpi_get_var1_double_all: unexpected value"); 

	MPI_Finalize();
	return 0; 
}
