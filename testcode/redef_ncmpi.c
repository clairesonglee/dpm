#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>
    
int main (void) {

	MPI_Init(NULL, NULL);
 
	int err, ncid;
	MPI_Info info;
    
	MPI_Info_create (&info);
	MPI_Info_set (info, "romio_no_indep_rw", "true");
	MPI_Info_set (info, "nc_header_read_chunk_size", "1024");
    
	err = ncmpi_open(MPI_COMM_WORLD, "foo.nc", NC_NOWRITE, info,  &ncid);
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));
	MPI_Info_free(&info);

	err = ncmpi_redef(ncid); /* enter define mode */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	MPI_Finalize();
	return 0; 
}
