set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'compare_bar.png'

set title "Comparative Performance for RegCMnoIO"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
set yrange [0:20000]

set xlabel "Problem Size"
set ylabel "Time (s)"
set key outside top right
set xtics rotate by -30
set bmargin 6

plot 'timing.dat' using 2:xtic(1) title 'Pure MPI(256proc)', \
     '' using 3 title '-stdpar=gpu', \
     '' using 4 title '-stdpar=multicore' 

