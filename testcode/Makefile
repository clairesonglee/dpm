MPICC		= mpicc
CFLAGS		= -O2

PnetCDF_DIR	= $(HOME)/PNETCDF/1.12.0

INCLUDES	= -I$(PnetCDF_DIR)/include -I.
LDFLAGS		= -L$(PnetCDF_DIR)/lib
LIBS		= -lpnetcdf $(shell $(PnetCDF_DIR)/bin/pnetcdf-config --libs)

all: create_ncmpi open_ncmpi

create_ncmpi: create_ncmpi.c
	$(MPICC) $(INCLUDES) -o create_ncmpi create_ncmpi.c $(LDFLAGS) $(LIBS)

open_ncmpi: open_ncmpi.c
	$(MPICC) $(INCLUDES) -o open_ncmpi open_ncmpi.c $(LDFLAGS) $(LIBS)

clean:
	rm create_ncmpi
	rm open_ncmpi
	rm foo.nc
