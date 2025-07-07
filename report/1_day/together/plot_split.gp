set terminal pngcairo size 1200,600 enhanced font 'Arial,12'
set output 'compare_split_bars.png'

set title "RegCMnoIO Runtime for Different Configurations"
set style data histogram
set style histogram rowstacked
set style fill solid border -1
set boxwidth 0.5
set xtics rotate by -30
set ylabel "Time (s)"
set yrange [0:*]

unset key
set bmargin 6

plot 'timing_split.dat' using 2:xtic(1) lc rgb "#406090"

