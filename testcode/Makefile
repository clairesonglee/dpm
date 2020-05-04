MPICC		= mpicc
CFLAGS		= -O2

PnetCDF_DIR	= $(HOME)/PNETCDF/1.12.0

INCLUDES	= -I$(PnetCDF_DIR)/include -I.
LDFLAGS		= -L$(PnetCDF_DIR)/lib
LIBS		= -lpnetcdf $(shell $(PnetCDF_DIR)/bin/pnetcdf-config --libs)

all: create_ncmpi open_ncmpi delete_ncmpi redef_ncmpi enddef_ncmpi sync_ncmpi getput_ncmpi test_dataset summation put_vara getput_var1 create_var getput_var

create_ncmpi: create_ncmpi.c
	$(MPICC) $(INCLUDES) -o create_ncmpi create_ncmpi.c $(LDFLAGS) $(LIBS)

open_ncmpi: open_ncmpi.c
	$(MPICC) $(INCLUDES) -o open_ncmpi open_ncmpi.c $(LDFLAGS) $(LIBS)

delete_ncmpi: delete_ncmpi.c
	$(MPICC) $(INCLUDES) -o delete_ncmpi delete_ncmpi.c $(LDFLAGS) $(LIBS)

redef_ncmpi: redef_ncmpi.c
	$(MPICC) $(INCLUDES) -o redef_ncmpi redef_ncmpi.c $(LDFLAGS) $(LIBS)

enddef_ncmpi: enddef_ncmpi.c
	$(MPICC) $(INCLUDES) -o enddef_ncmpi enddef_ncmpi.c $(LDFLAGS) $(LIBS)

sync_ncmpi: sync_ncmpi.c
	$(MPICC) $(INCLUDES) -o sync_ncmpi sync_ncmpi.c $(LDFLAGS) $(LIBS)

getput_ncmpi: getput_ncmpi.c
	$(MPICC) $(INCLUDES) -o getput_ncmpi getput_ncmpi.c $(LDFLAGS) $(LIBS)

test_dataset: test_dataset.c
	$(MPICC) $(INCLUDES) -o test_dataset test_dataset.c $(LDFLAGS) $(LIBS)

summation: summation.c
	$(MPICC) $(INCLUDES) -o summation summation.c $(LDFLAGS) $(LIBS)

put_vara: put_vara.c
	$(MPICC) $(INCLUDES) -o put_vara put_vara.c $(LDFLAGS) $(LIBS)

getput_var1: getput_var1.c
	$(MPICC) $(INCLUDES) -o getput_var1 getput_var1.c $(LDFLAGS) $(LIBS)

create_var: create_var.c
	$(MPICC) $(INCLUDES) -o create_var create_var.c $(LDFLAGS) $(LIBS)

getput_var: getput_var.c
	$(MPICC) $(INCLUDES) -o getput_var getput_var.c $(LDFLAGS) $(LIBS)

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
	rm put_vara
	rm getput_var1
	rm create_var
	rm getput_var
