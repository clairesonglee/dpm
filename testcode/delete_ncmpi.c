#include <pnetcdf.h>
#include <stdio.h>
#include <mpi.h>

int main(void) {
	MPI_Init(NULL, NULL);

	int status;
	MPI_Info info = MPI_INFO_NULL;
	status = ncmpi_delete("foo.nc", info);

	MPI_Finalize();
}
