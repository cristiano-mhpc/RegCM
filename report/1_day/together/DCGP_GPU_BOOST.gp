set terminal pngcairo size 1000,600 enhanced font 'Arial,10'
set output 'pureMPIvsGPU_plot.png'

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
set bmargin 6

plot 'DCGP_GPU_BOOST.dat' using 2:xtic(1) title '8nodesBoost(256proc)', \
     '' using 3 title '-stdpar=gpu', \
     '' using 4 title '8nodesDCGP(896proc)', \
     '' using ($0 + 0.08):3:5 with labels offset 0,1 notitle

