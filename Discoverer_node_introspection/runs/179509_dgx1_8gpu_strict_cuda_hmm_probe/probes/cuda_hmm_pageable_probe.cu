#include <cstdio>
#include <cstdlib>
#include <cuda_runtime.h>

__global__ void add_kernel(double *a, int n) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i < n) a[i] += 2.0;
}

int main() {
  int device = 0;
  cudaError_t status = cudaSetDevice(device);
  if (status != cudaSuccess) {
    std::fprintf(stderr, "cudaSetDevice failed: %s\n", cudaGetErrorString(status));
    return 2;
  }

  int pageable = 0;
  int concurrent_managed = 0;
  int managed = 0;
  cudaDeviceGetAttribute(&pageable, cudaDevAttrPageableMemoryAccess, device);
  cudaDeviceGetAttribute(&concurrent_managed, cudaDevAttrConcurrentManagedAccess, device);
  cudaDeviceGetAttribute(&managed, cudaDevAttrManagedMemory, device);
  std::printf("cudaDevAttrPageableMemoryAccess=%d\n", pageable);
  std::printf("cudaDevAttrConcurrentManagedAccess=%d\n", concurrent_managed);
  std::printf("cudaDevAttrManagedMemory=%d\n", managed);

  const int n = 1 << 20;
  double *a = static_cast<double *>(std::malloc(n * sizeof(double)));
  if (!a) {
    std::fprintf(stderr, "malloc failed\n");
    return 3;
  }

  for (int i = 0; i < n; ++i) a[i] = 1.0;

  cudaPointerAttributes attrs;
  status = cudaPointerGetAttributes(&attrs, a);
  std::printf("cudaPointerGetAttributes_status=%s\n", cudaGetErrorString(status));
  cudaGetLastError();

  add_kernel<<<(n + 255) / 256, 256>>>(a, n);
  status = cudaGetLastError();
  if (status != cudaSuccess) {
    std::fprintf(stderr, "kernel launch failed: %s\n", cudaGetErrorString(status));
    std::free(a);
    return 4;
  }

  status = cudaDeviceSynchronize();
  if (status != cudaSuccess) {
    std::fprintf(stderr, "kernel sync failed: %s\n", cudaGetErrorString(status));
    std::free(a);
    return 5;
  }

  double err = 0.0;
  for (int i = 0; i < n; ++i) err += (a[i] == 3.0) ? 0.0 : 1.0;
  std::free(a);

  if (err != 0.0) {
    std::fprintf(stderr, "verification failed: bad_count=%e\n", err);
    return 6;
  }

  std::printf("cuda_hmm_pageable_probe: PASS\n");
  return 0;
}
