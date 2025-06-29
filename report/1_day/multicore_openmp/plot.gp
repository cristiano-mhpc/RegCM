set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'bar_timing.png'

set title "Hybrid Configurations RegCMnoIO"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
set yrange [0:100000]

set xlabel "Problem Size"
set ylabel "Time (s)"
set key outside top right
set xtics rotate by -30

plot 'timing.dat' using 2:xtic(1) title '1MPIx32th(1node)', \
     '' using 3 title '2MPIx16th(1node)', \
     '' using 4 title '4MPIx8th(1node)', \
     '' using 5 title '8MPIx8th(2node)', \
     '' using 6 title '16MPIx8th(4node)'

