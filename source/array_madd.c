// Frama-C + HLS Benchmark: array_madd
// Kernel: for i = 0..N-1, a[i] += b[i]*b[i] + c[i]*c[i]
// Translation: Leiqi Ye

#ifndef __SYNTHESIS__
#include <stdio.h>
#endif

#define N 1024
#define BC_MAX 100
#define A_MAX 1000000000

#ifdef FRAMAC
/*@
  assigns \nothing;
  ensures \true;
*/
int printf(const char *fmt, ...) { return 0; }
#endif

/*@
  requires \valid(a + (0 .. N-1));
  requires \valid_read(b + (0 .. N-1));
  requires \valid_read(c + (0 .. N-1));
  requires \separated(a + (0 .. N-1), b + (0 .. N-1));
  requires \separated(a + (0 .. N-1), c + (0 .. N-1));
  requires \forall integer k; 0 <= k < N ==> -BC_MAX <= b[k] <= BC_MAX;
  requires \forall integer k; 0 <= k < N ==> -BC_MAX <= c[k] <= BC_MAX;
  requires \forall integer k; 0 <= k < N ==> -A_MAX <= a[k] <= A_MAX;
  assigns a[0 .. N-1];
  ensures \forall integer k; 0 <= k < N ==>
          a[k] == \old(a[k]) + (b[k]*b[k] + c[k]*c[k]);
*/
void array_madd(int a[N], int b[N], int c[N]) {
  /*@
    loop invariant 0 <= i <= N;
    loop invariant \forall integer k; 0 <= k < i ==>
                   a[k] == \at(a[k], Pre) + (b[k]*b[k] + c[k]*c[k]);
    loop invariant \forall integer k; i <= k < N ==>
                   a[k] == \at(a[k], Pre);
    loop assigns i, a[0 .. N-1];
    loop variant N - i;
  */
  for (int i = 0; i < N; i++) {
    a[i] += b[i] * b[i] + c[i] * c[i];
  }
}

/*@
  requires \valid(a + (0 .. N-1));
  requires \valid_read(b + (0 .. N-1));
  requires \valid_read(c + (0 .. N-1));
  requires \separated(a + (0 .. N-1), b + (0 .. N-1));
  requires \separated(a + (0 .. N-1), c + (0 .. N-1));
  requires \forall integer k; 0 <= k < N ==> -BC_MAX <= b[k] <= BC_MAX;
  requires \forall integer k; 0 <= k < N ==> -BC_MAX <= c[k] <= BC_MAX;
  requires \forall integer k; 0 <= k < N ==> -A_MAX <= a[k] <= A_MAX;
  assigns a[0 .. N-1];
  ensures \forall integer k; 0 <= k < N ==>
          a[k] == \old(a[k]) + (b[k]*b[k] + c[k]*c[k]);
*/
void array_madd_top(int a[N], int b[N], int c[N]) {
  // HLS top-level wrapper.
  // No INTERFACE pragmas: arrays default to ap_memory/BRAM ports internal
  // to the module. External memory (m_axi) is intentionally avoided so the
  // RTL formal flow never has to model a memory subsystem.
  array_madd(a, b, c);
}

#ifndef __SYNTHESIS__
/*@
  assigns \nothing;
  ensures \true;
*/
int main(void) {
  int a[N];
  int b[N];
  int c[N];

  /*@ loop invariant 0 <= i <= N;
      loop invariant \forall integer k; 0 <= k < i ==> a[k] == k;
      loop invariant \forall integer k; 0 <= k < i ==> b[k] == 1;
      loop invariant \forall integer k; 0 <= k < i ==> c[k] == 2;
      loop assigns i, a[0 .. N-1], b[0 .. N-1], c[0 .. N-1];
      loop variant N - i;
  */
  for (int i = 0; i < N; i++) {
    a[i] = i;
    b[i] = 1;
    c[i] = 2;
  }

  array_madd(a, b, c);

  printf("a[0]=%d a[1]=%d a[N-1]=%d\n", a[0], a[1], a[N-1]);
  return 0;
}
#endif
