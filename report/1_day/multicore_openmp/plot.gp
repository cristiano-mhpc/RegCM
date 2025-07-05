set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'plot_log.png'

set title "Hybrid Configurations RegCMnoIO"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
set yrange [1000:90000]

set logscale y 


set xlabel "Problem Size"
set ylabel "Time (s)"
set key outside top right
set xtics rotate by -30

plot 'timing.dat' using 2:xtic(1) title '1procx32thr', \
     '' using 3 title '2procx16thr', \
     '' using 4 title '4procx8thr', \
     '' using 5 title '8procx8thr', \
     '' using 6 title '16procx8thr', \
     '' using 7 title '32procx8thr', \
     '' using 8 title '64procx8thr'

