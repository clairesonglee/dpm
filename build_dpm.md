# Darshan-PNetCDF Commands  

## Running DPM testcode files
'make install' in darshan source code directory (darshan-runtime)
'make clean && make' in testcode directory (testcode)
'mpirun -n 1 ./executable name' in same directory to run executable

## Generating darshan-job-summary PDF file  
./darshan-job-summary.pl ~/darshan-logs/2020/1/25/csl782_executable_name_id*.darshan 

To specify an output name, run the command
./darshan-job-summary.pl ~/darshan-logs/2020/1/25/csl782_executable_name_id*.darshan --output output_name 

## Utilizing darshan-dxt-parser for *.txt file 
darshan-dxt-parser ~/darshan-logs/2020/1/25/csl782_executable_name_id*.darshan > output.txt