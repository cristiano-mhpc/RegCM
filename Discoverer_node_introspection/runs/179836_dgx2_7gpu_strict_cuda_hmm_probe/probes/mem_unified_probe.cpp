#include <cstdio>
#include <cstdlib>
#include <cmath>

int main() {
  const int n = 1 << 20;
  double *a = static_cast<double*>(std::malloc(n * sizeof(double)));
  if (!a) {
    std::fprintf(stderr, "malloc failed\n");
    return 2;
  }

  for (int i = 0; i < n; ++i) a[i] = 1.0;

  // Intentionally no OpenACC data region/copy clause here.
  // With -gpu=mem:unified, this probes whether system-allocated host memory
  // can be accessed/migrated correctly by the GPU runtime on this node.
  #pragma acc parallel loop
  for (int i = 0; i < n; ++i) {
    a[i] = a[i] + 2.0;
  }

  double err = 0.0;
  for (int i = 0; i < n; ++i) err += std::fabs(a[i] - 3.0);
  std::free(a);

  if (err != 0.0) {
    std::fprintf(stderr, "verification failed: err=%e\n", err);
    return 3;
  }

  std::printf("mem_unified_probe: PASS\n");
  return 0;
}
