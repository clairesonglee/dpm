#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#define n 100

int main(int argc, char* argv[])
{
	MPI_Status status;
	int rank, num_proc;

	MPI_Init(&argc, &argv);

	MPI_Comm_rank(MPI_COMM_WORLD, &rank);
	MPI_Comm_size(MPI_COMM_WORLD, &num_proc); 
 
	// Input array initialization
	int i, a[n];
	for (i = 0; i < n; i++) {
		a[i] = i+1;
	}

	int local_sum = 0, num_elem = n/num_proc;

 	// Send array to all processes and compute local sum
	MPI_Bcast(a, num_elem, MPI_INT, 0, MPI_COMM_WORLD);
	for (i = 0; i < num_elem; i++) {
		local_sum += a[rank * num_elem + i];
	}
	printf("Rank of current process is %d and local sum is %d\n", rank, local_sum);

	// Collect all partial sums to root process and print total sum
	int global_sum;
	MPI_Reduce(&local_sum, &global_sum, 1, MPI_INT, MPI_SUM, 0, MPI_COMM_WORLD);
	if (rank == 0) {
		printf("Sum of input array is: %d\n", global_sum);
	}

	MPI_Finalize();
	return 0;
}
