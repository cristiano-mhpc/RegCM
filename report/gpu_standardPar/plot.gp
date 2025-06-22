set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'timing_bar_plot.png'

set title "Timing for Different GPU + MPI Configurations"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'

set xlabel "Problem Size"
set ylabel "Time (ms)"
set key outside top right
set xtics rotate by -30

plot 'timing.dat' using 2:xtic(1) title '1GPU_1MPI', \
     '' using 3 title '2GPU2MPI', \
     '' using 4 title '4GPU4MPI', \
     '' using 5 title '8GPU8MPI', \
     '' using 6 title '16GPU16MPI'

