# darshan-pnetcdf-component

Instructions to run additional PNETCDF functions:
configure darshan-runtime: 
./configure --prefix=$HOME/DARSHAN/3.1.8 --enable-group-readable-logs --with-mem-align=8 --with-log-path=/files4/home/csl782/darshan-logs --with-jobid-env=PBS_JOBID CC=mpicc 

create output pdf file: 
./darshan-job-summary.pl name-output-file.darshan

Currently supported PNETCDF functions:
create_ncmpi
open_ncmpi
delete_ncmpi
close_ncmpi  
