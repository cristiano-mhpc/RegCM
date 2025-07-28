set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'timing.png'

set title "Performance for with Nvidia MPS"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
#set yrange [0:8000]
set yrange [0:*]

#set logscale y 

set xlabel "Problem Size"
set ylabel "Time (s)" 
set key outside top right
set xtics rotate by -30

plot 'timing.dat' using 2:xtic(1) title '1MPI', \
     '' using 3 title '2MPI', \
     '' using 4 title '4MPI', \
     '' using 5 title '8MPI', \
     '' using 6 title '16MPI'

