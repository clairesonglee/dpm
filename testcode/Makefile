MPICC		= mpicc
CFLAGS		= -O0 -g
#CFLAGS		= -O2

PnetCDF_DIR	= $(HOME)/PNETCDF/1.12.0

INCLUDES	= -I$(PnetCDF_DIR)/include -I.
LDFLAGS		= -L$(PnetCDF_DIR)/lib
LIBS		= -lpnetcdf $(shell $(PnetCDF_DIR)/bin/pnetcdf-config --libs)

all: create_ncmpi open_ncmpi delete_ncmpi redef_ncmpi enddef_ncmpi sync_ncmpi getput_ncmpi test_dataset summation getput_var put_vara put_varn_float put_varn_int get_vara create_open

create_ncmpi: create_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o create_ncmpi create_ncmpi.c $(LDFLAGS) $(LIBS)

open_ncmpi: open_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o open_ncmpi open_ncmpi.c $(LDFLAGS) $(LIBS)

delete_ncmpi: delete_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o delete_ncmpi delete_ncmpi.c $(LDFLAGS) $(LIBS)

redef_ncmpi: redef_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o redef_ncmpi redef_ncmpi.c $(LDFLAGS) $(LIBS)

enddef_ncmpi: enddef_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o enddef_ncmpi enddef_ncmpi.c $(LDFLAGS) $(LIBS)

sync_ncmpi: sync_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o sync_ncmpi sync_ncmpi.c $(LDFLAGS) $(LIBS)

getput_ncmpi: getput_ncmpi.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o getput_ncmpi getput_ncmpi.c $(LDFLAGS) $(LIBS)

test_dataset: test_dataset.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o test_dataset test_dataset.c $(LDFLAGS) $(LIBS)

summation: summation.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o summation summation.c $(LDFLAGS) $(LIBS)

getput_var: getput_var.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o getput_var getput_var.c $(LDFLAGS) $(LIBS)

put_vara: put_vara.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o put_vara put_vara.c $(LDFLAGS) $(LIBS)

put_varn_float: put_varn_float.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o put_varn_float put_varn_float.c $(LDFLAGS) $(LIBS)

put_varn_int: put_varn_int.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o put_varn_int put_varn_int.c $(LDFLAGS) $(LIBS)

get_vara: get_vara.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o get_vara get_vara.c $(LDFLAGS) $(LIBS)

create_open: create_open.c
	$(MPICC) $(CFLAGS) $(INCLUDES) -o create_open create_open.c $(LDFLAGS) $(LIBS)

clean:
	rm create_ncmpi
	rm open_ncmpi
	rm delete_ncmpi
	rm redef_ncmpi
	rm enddef_ncmpi
	rm sync_ncmpi
	rm getput_ncmpi
	rm test_dataset
	rm summation
	rm getput_var
	rm put_vara
	rm put_varn_float
	rm put_varn_int
	rm get_vara
	rm create_open 
