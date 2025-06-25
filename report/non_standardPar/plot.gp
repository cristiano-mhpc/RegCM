set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'bar_plot.png'
set title "Performance for -acc=gpu"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
set yrange [0:80000]


set xlabel "Problem Size"
set ylabel "Time (s)"
set key outside top right
set xtics rotate by -30

plot 'timing.dat' using 2:xtic(1) title '1GPU+1MPI', \
     '' using 3 title '2MPIx16th(1node)', \
     '' using 4 title '4MPIx8th(1node)', \
     '' using 5 title '8MPIx8th(2nodes)', \
     '' using 6 title '16MPIx8th(4nodes)'

