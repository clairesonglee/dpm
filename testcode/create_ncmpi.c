#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>

int main (void) { 
	MPI_Init(NULL, NULL);

	int err_create, err_close, ncid, cmode = NC_CLOBBER | NC_64BIT_DATA;
	MPI_Info info;

	err_create = ncmpi_create(MPI_COMM_WORLD, "foo.nc", cmode, MPI_INFO_NULL, &ncid);
	if (err_create != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err_create));
	

	/* create dimensions, variables, attributes, write/read variables */

	err_close = ncmpi_close(ncid);       /* close netCDF file */
	if (err_close != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err_close));

	MPI_Finalize();
	return 0; 
}
