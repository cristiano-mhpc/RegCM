set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'timing_plot.png'

set title "Timing vs Configuration"
set xlabel "Problem Size"
set ylabel "Time (ms)"
set datafile missing '---'

set style data linespoints
set key outside

plot 'timing.dat' using 0:2:xtic(1) title '1GPU_1MPI', \
     '' using 0:3 title '2GPU_2MPI', \
     '' using 0:4 title '4GPU_4MPI', \
     '' using 0:5 title '8GPU_8MPI', \
     '' using 0:6 title '16GPU_16MPI'

