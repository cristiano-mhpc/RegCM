set terminal pngcairo size 1000,600 enhanced font 'Arial,10'
set output 'CPU_partition.png'

set title "Comparative Performance for RegCMnoIO"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile separator whitespace
set yrange [0:*]

set xlabel "Problem Size"
set ylabel "Time (s)"
set key outside top right
#set xtics rotate by -30
set bmargin 6

# Plot only MPI and GPU bars, with GPU labels
plot 'CPU_partition.dat' using 2:xtic(1) title 'Pure MPI(256proc)', \
     '' using 3 title '-stdpar=gpu', \
     '' using ($0 + 0.25):3:4 with labels offset 0,1 notitle

