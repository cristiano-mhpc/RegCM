set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'compare_bar.png'

set title "Comparative Performance for RegCMnoIO"
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
set bmargin 6

plot 'timing.dat' using 2:xtic(1) title '-acc=gpu(16GPU+16MPI)', \
     '' using 3 title '-stdpar=gpu(2GPU+2MPI)', \
     '' using 4 title '-stdpar=multicore(16MPIx8Th(4nodes))' 

