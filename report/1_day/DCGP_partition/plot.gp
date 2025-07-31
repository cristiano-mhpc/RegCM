set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'timing_plot.png'

set title "Performance for various MPI Configurations on DCGP"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
set yrange [0:*]

# set logscale y 

set xlabel "Problem Size"
set ylabel "Time (s)" 
set key outside top right
# set xtics rotate by -30

plot 'timing.dat' using 2:xtic(1) title '112Proc', \
     '' using 3 title '224Proc', \
     '' using 4 title '448Proc', \
     '' using 5 title '896Proc'

