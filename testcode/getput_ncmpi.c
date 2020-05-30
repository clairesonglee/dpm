#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>
    
int main (void) {

	MPI_Init(NULL, NULL);
 
	int err, ncid, varid, cmode = NC_CLOBBER;

	err = ncmpi_create(MPI_COMM_WORLD, "test_getput.nc", cmode, MPI_INFO_NULL, &ncid); 
	if(err != NC_NOERR) printf("Error: %s\n", ncmpi_strerror(err));

	int lat_dim, lon_dim, time_dim;
	int rh_id;
	int rh_dimids[3];

	err = ncmpi_def_dim(ncid, "lat", 5L, &lat_dim);
	if (err != NC_NOERR) printf("ncmpi_def_dim: %s\n", ncmpi_strerror(err));
	err = ncmpi_def_dim(ncid, "lon", 10L, &lon_dim);
	if (err != NC_NOERR) printf("ncmpi_def_dim: %s\n", ncmpi_strerror(err));
	err = ncmpi_def_dim(ncid, "time", NC_UNLIMITED, &time_dim);
	if (err != NC_NOERR) printf("ncmpi_def_dim: %s\n", ncmpi_strerror(err));

	rh_dimids[0] = time_dim;
	rh_dimids[1] = lat_dim;
	rh_dimids[2] = lon_dim;
	err = ncmpi_def_var(ncid, "rh", NC_DOUBLE, 3, rh_dimids, &rh_id); 
	if (err != NC_NOERR) printf("ncmpi_def_var: %s\n", ncmpi_strerror(err));

	err = ncmpi_enddef(ncid); 
	if (err != NC_NOERR) printf("Error: %s\n",ncmpi_strerror(err));

	MPI_Offset rh_index[] = {1, 2, 3};
	double rh_val = 0.5;

	/*
	err = ncmpi_inq_varid(ncid, "d", &varid);
	if(err != NC_NOERR) printf("ncmpi_inq_varid: %s\n", ncmpi_strerror(err)); 
	*/

	/* independently write single data value to file */
	/*
	err = ncmpi_begin_indep_data(ncid);
	err = ncmpi_put_var1_int(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_put_var1_int: %s\n", ncmpi_strerror(err));
	err = ncmpi_end_indep_data(ncid);
	*/

	/* collectively write single data value to file */
	err = ncmpi_put_var1_double_all(ncid, rh_id, rh_index, &rh_val);
	if (err != NC_NOERR) printf("ncmpi_put_var1_double_all: %s\n", ncmpi_strerror(err));

	/* independently read single data value from file */
	/*
	err = ncmpi_begin_indep_data(ncid);
	err = ncmpi_get_var1_double(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_get_var1_double: %s\n", ncmpi_strerror(err));
	if (var != 1.0) printf("ncmpi_get_var1_double: unexpected value"); 
	err = ncmpi_end_indep_data(ncid);
	*/

	/* collectively read single data value from file */
	/*
	err = ncmpi_get_var1_double_all(ncid, varid, NULL, &var);
	if (err != NC_NOERR) printf("ncmpi_get_var1_double_all: %s\n", ncmpi_strerror(err));
	if (var != 1.0) printf("ncmpi_get_var1_double_all: unexpected value"); 
	*/

	err = ncmpi_close(ncid);
	if (err != NC_NOERR) printf("ncmpi_close: %s\n", ncmpi_strerror(err));

	MPI_Finalize();
	return 0; 
}
