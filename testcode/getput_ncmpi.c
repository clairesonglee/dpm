#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>
    
int main (void) {

	MPI_Init(NULL, NULL);
 
	int err, ncid, varid;
	MPI_Info info;
    
	MPI_Info_create (&info);
	MPI_Info_set (info, "romio_no_indep_rw", "true");
	MPI_Info_set (info, "nc_header_read_chunk_size", "1024");
    
	err = ncmpi_open(MPI_COMM_WORLD, "foo.nc", NC_WRITE, info,  &ncid);
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));
	MPI_Info_free(&info);

	err = ncmpi_redef(ncid); /* enter define mode */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	err = ncmpi_enddef(ncid); /* exit define mode */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	err = ncmpi_sync(ncid); /* synchronize to disk */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	double var = 1.0; /* initialize temporary variable */

	/* independently write single data value to file */
	err = ncmpi_put_var1_double(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_put_var1_double: %s", ncmpi_strerror(err));

	/* collectively write single data value to file */
	err = ncmpi_put_var1_double_all(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_put_var1_double_all: %s", ncmpi_strerror(err));

	/* independently read single data value from file */
	err = ncmpi_get_var1_double(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_get_var1_double: %s", ncmpi_strerror(err));
	if (var != 1.0) printf("ncmpi_get_var1_double: unexpected value"); 

	/* collectively read single data value from file */
	err = ncmpi_get_var1_double_all(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_get_var1_double_all: %s", ncmpi_strerror(err));
	if (var != 1.0) printf("ncmpi_get_var1_double_all: unexpected value"); 


	err = ncmpi_close(ncid); 

	MPI_Finalize();
	return 0; 
}
