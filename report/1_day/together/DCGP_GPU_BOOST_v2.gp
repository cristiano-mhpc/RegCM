set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'pureMPIvsGPU.png'

set title "Comparative Performance for RegCMnoIO"
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

plot 'DCGP_GPU_BOOST_v2.dat' using 2:xtic(1) title '8nodesBooster(256proc)', \
     '' using 3 title '8nodesDCGP(896proc)', \
     '' using 4 title '4GPU+4Proc', \
     '' using 5 title '8GPU+8Proc',\
     '' using 6 title '16GPU+16Proc'

