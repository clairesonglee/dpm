#include <stdio.h>
#include <mpi.h>
#include <pnetcdf.h>

#define ERR {if(err!=NC_NOERR){printf("Error at %s:%d : %s\n", __FILE__,__LINE__, ncmpi_strerror(err));}}

#define TIMES 3
#define LATS 5
#define LONS 10 

int create_file (MPI_Comm comm, char *filename, int cmode) {
 
	int err, ncid;

	err = ncmpi_create(comm, filename, cmode, MPI_INFO_NULL, &ncid); 
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

	err = ncmpi_enddef(ncid); ERR
	
	return 0; 
}

int put_var (MPI_Comm comm, char *filename, int cmode) {
	int  err;                       /* error status */
	int  rank; 
	int  ncid;                         /* netCDF ID */
	int  rh_id;                        /* variable ID */
	double rh_vals[TIMES*LATS*LONS];   /* array to hold values */
	int i;

	err = ncmpi_open(comm, filename, NC_WRITE, MPI_INFO_NULL, &ncid); ERR
	
	err = ncmpi_begin_indep_data(ncid); ERR

	err = ncmpi_inq_varid(ncid, "rh", &rh_id); ERR

	for ( i = 0; i < TIMES*LATS*LONS; i++)
		rh_vals[i] = 0.5; 

	MPI_Comm_rank(comm, &rank);
	if (rank == 0) {
		err = ncmpi_put_var_double(ncid, rh_id, rh_vals); ERR 
	}

	err = ncmpi_end_indep_data(ncid);
	if (err != NC_NOERR); ERR 
}

int put_var1_all (MPI_Comm comm, char *filename, int cmode) {

	int err, rank, ncid;
	int rh_id; 
	MPI_Offset rh_index[] = {1, 2, 3};
	double rh_val = 0.5 + rank;

	/* Open file in write mode */
	err = ncmpi_open(comm, filename, NC_WRITE, MPI_INFO_NULL,  &ncid); ERR

	err = ncmpi_inq_varid(ncid, "rh", &rh_id); ERR

	/* collectively write single data value to file */
	err = ncmpi_put_var1_double_all(ncid, rh_id, rh_index, &rh_val); ERR

	/* collectively read single data value from file */
	/*
	err = ncmpi_get_var1_double_all(ncid, rh_id, rh_index, &rh_val); ERR
	printf("rh_val is %d\n", rh_val); 
	if (rh_val != 0.5) printf("ncmpi_get_var1_double: unexpected value"); 
	*/
	err = ncmpi_close(ncid); ERR

	return 0; 
}
  
int put_vara_all (MPI_Comm comm, char *filename, int cmode) {
	int err, ncid, rh_id, rank;
	MPI_Offset start[3];
	MPI_Offset count[3];
	double rh_vals[TIMES*LATS*LONS];
	
	/* create file with specified variables */
	//err = ncmpi_create(MPI_COMM_WORLD, filename, cmode, MPI_INFO_NULL, &ncid); 

	/* leave define mode */
	//err = ncmpi_enddef(ncid);

	/* open file in writeable mode */
	err = ncmpi_open(comm, filename, NC_WRITE, MPI_INFO_NULL,  &ncid); ERR
    
	/* obtain variable ID */
	err = ncmpi_inq_varid(ncid, "rh", &rh_id); ERR
   
	/* set the starting indices and write lengths for this process */
	MPI_Comm_rank(comm, &rank);
	start[0] = 3;
	start[1] = 0;
	start[2] = LONS * rank;
	count[0] = 1;
	count[1] = LATS;
	count[2] = LONS;
   
	/* set the write contents */
	int i; 
	for (i=0; i<TIMES*LATS*LONS; i++)
    		rh_vals[i] = 0.5 + rank;

	/* collectively write a record into variable "rh" */
	err = ncmpi_put_vara_double_all(ncid, rh_id, start, count, rh_vals); ERR

	err = ncmpi_close(ncid); ERR

	return 0; 
}

  
int main (void) {

	MPI_Init(NULL, NULL);

	MPI_Comm comm = MPI_COMM_WORLD; 		
	char* filename = "test_put_var.nc";
	int cmode = NC_CLOBBER; 

	create_file (comm, filename, cmode); 
	put_var (comm, filename, cmode); 
	put_var1_all (comm, filename, cmode); 
	put_vara_all (comm, filename, cmode); 

	MPI_Finalize();
	return 0; 
}