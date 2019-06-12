#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define N 64



#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)



float sample_A[N] __attribute__ ((section (".dram"))) = {
47.380930, -48.647220, 13.272060, 42.545490, 
37.735540, 9.857860, -31.216140, 36.042080, 
26.557710, 36.012680, -5.595430, 0.289350, 
41.982440, -46.674430, -5.527890, -13.399410, 
-28.790430, -18.836100, 40.348570, -45.155220, 
38.182440, -22.133690, 21.056050, -13.207270, 
43.136370, 45.024090, 49.063260, 40.064220, 
29.376800, -0.432250, -46.107920, 12.751940, 
-47.199400, 5.021170, -6.250430, 9.454550, 
-17.044750, 41.444510, 32.130250, -16.660950, 
-37.625460, -17.715150, -37.103340, -30.783900, 
-10.028670, 25.547450, -9.303800, 20.391060, 
-38.555720, -12.435480, -48.448220, -6.717880, 
37.739960, 17.551320, -28.181800, -38.832420, 
17.040110, 1.942650, -46.474350, 14.451750, 
-11.033170, -7.206880, -46.623000, 41.460570
};




float sample_B[N] __attribute__ ((section (".dram"))) = {
-12.670940, 24.153630, 1.039480, 48.181160, 
-35.495200, -5.205460, 15.294680, 47.539440, 
9.148080, 24.535330, -11.745840, -6.410890, 
-40.820080, 33.964210, -11.136210, -13.974210, 
47.668310, -23.474240, 17.123090, -38.045460, 
11.295550, -38.332830, 24.288640, -30.131690, 
1.217060, 47.391310, -41.883240, 29.731430, 
11.146140, -33.091960, -1.731370, -13.626460, 
30.787290, 48.720740, -42.258800, -5.032420, 
29.349000, 29.507000, -39.603220, -38.358380, 
24.620600, -25.139180, 17.601760, -27.505120, 
29.069140, 36.466660, -12.290530, 34.483530, 
21.996060, -39.543880, 30.480230, 16.936040, 
8.751880, 40.776130, 8.046750, -2.049960, 
19.059290, -22.528180, 39.530670, 48.297910, 
-28.297820, -13.169720, -26.472540, -5.681980
};




float sample_C[N] __attribute__ ((section (".dram"))) = {
34.709990, -24.493590, 14.311540, 90.726650, 
2.240340, 4.652400, -15.921460, 83.581520, 
35.705790, 60.548010, -17.341270, -6.121540, 
1.162360, -12.710220, -16.664100, -27.373620, 
18.877880, -42.310340, 57.471660, -83.200680, 
49.477990, -60.466520, 45.344690, -43.338960, 
44.353430, 92.415400, 7.180020, 69.795650, 
40.522940, -33.524210, -47.839290, -0.874520, 
-16.412110, 53.741910, -48.509230, 4.422130, 
12.304250, 70.951510, -7.472970, -55.019330, 
-13.004860, -42.854330, -19.501580, -58.289020, 
19.040470, 62.014110, -21.594330, 54.874590, 
-16.559660, -51.979360, -17.967990, 10.218160, 
46.491840, 58.327450, -20.135050, -40.882380, 
36.099400, -20.585530, -6.943680, 62.749660, 
-39.330990, -20.376600, -73.095540, 35.778590
};











#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);



float A[N] __attribute__ ((section (".dram")));
float B[N] __attribute__ ((section (".dram")));
float C[N] __attribute__ ((section (".dram")));


void initialize_input (float *A, float *B, float *C, float size) { 
	for (int i = __bsg_id; i < size; i += bsg_tiles_X * bsg_tiles_Y) {
		A[i] = sample_A[i];
		B[i] = sample_B[i];
		C[i] = 0.0; 
	}
	return;
}


void vector_add (float *A, float *B, float *C, float size) { 

	for (int i = __bsg_id; i < size; i += bsg_tiles_X * bsg_tiles_Y) { 
		C[i] = A[i] + B[i];
	}	
	return;
}



int main()
{
	bsg_set_tile_x_y();


	initialize_input(A, B, C, N);


	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	vector_add (A, B, C, N); 


	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	if (__bsg_id == 0) { 
		for (int i = 0; i < N; i ++) { 
			if (C[i] == sample_C[i]) { 
				bsg_printf("PASS -- C[%d] = 0x%x\t Expected: 0x%x.\n", i, hex(C[i]), hex(sample_C[i]));
			}
			else { 
				bsg_printf("FAIL -- C[%d] = 0x%x\t Expected: 0x%x.\n", i, hex(C[i]), hex(sample_C[i]));
			}
		}
	}
	

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	bsg_finish();


	bsg_wait_while(1);
}