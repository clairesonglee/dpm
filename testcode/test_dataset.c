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
    
	err = ncmpi_open(MPI_COMM_WORLD, "test.nc", NC_WRITE, info,  &ncid);
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));
	MPI_Info_free(&info);

	/* test stdio timing */
	printf("ERROR IS %d\n", err);

	/* write data or change attributes */

	err = ncmpi_redef(ncid); /* enter define mode */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	/* define or change dimensions, variables, and attributes */
	//ncmpi_def_dim();
	int i, sum = 0; 
	for(int i = 0; i < 10; i++)
		sum += i; 
	printf("Total sum: %d\n", sum);

	err = ncmpi_enddef(ncid); /* exit define mode */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	/* write data or change attributes */

	err = ncmpi_sync(ncid); /* synchronize to disk */
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	MPI_Finalize();
	return 0; 
}
