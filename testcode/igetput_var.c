#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>

int         i;
int         ncid;           /* netCDF ID */
int         varid;          /* variable ID */
int         status;         /* error status */
int         request[10];    /* nonblocking request ID */
int         statuses[10];   /* status for individual requests */
MPI_Offset  start[10][2];   /* 10 sets of start indices */
MPI_Offset  count[10][2];   /* 10 sets of count lengths */
double     *buffers[10];    /* 10 write buffers */

status = ncmpi_create(MPI_COMM_WORLD, "foo.nc", NC_WRITE, MPI_INFO_NULL, &ncid);
if (status != NC_NOERR) handle_error(status);
/* define dimensions */
/* define variables */
/* set values for start and count */
/* allocate write buffers and assign their values */

for (i=0; i<10; i++) {
    /* post a nonblocking write request */
    status = ncmpi_iput_vara_double(ncid, varid, start[i], count[i], buffers[i], &request[i]);
    if (status != NC_NOERR) handle_error(status);
}

/* write all 10 requests to the file at once */
status = ncmpi_wait_all(ncid, 10, request, statuses);
if (status != NC_NOERR) handle_error(status);

for (i=0; i<10; i++) /* check status for each request */
    if (statuses[i] != NC_NOERR)
        handle_error(statuses[i]);

