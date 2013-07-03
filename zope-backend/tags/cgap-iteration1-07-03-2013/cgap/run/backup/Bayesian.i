/* Bayesian.i */
     %module Bayesian
     %{
     /* Put header files here or function declarations like below */
     extern long double power( long double base, int n );
     extern long double f(double x, int a, int b, double A, double B);
     extern double func(double x, int a, int b, double A, double B);
     extern double Bayesian(double factor, int a, int b, double A, double B);
     %}
     
     extern long double power( long double base, int n );
     extern long double f(double x, int a, int b, double A, double B);
     extern double func(double x, int a, int b, double A, double B);
      extern double Bayesian(double factor, int a, int b, double A, double B);

