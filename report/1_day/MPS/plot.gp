set terminal pngcairo size 1000,600 enhanced font 'Arial,12'
set output 'timing.png'

set title "Performance with Multiprocess Service (MPS) of RegCM4 on 512x1024x60 Grid"
set style data histogram
set style histogram cluster gap 1
set style fill solid border -1
set boxwidth 0.9
set datafile missing '---'
#set yrange [0:8000]
set yrange [0:*]

#set logscale y 

set xlabel "Number of A100 GPUs"
set ylabel "Time (s)" 
set key outside top right
#set xtics rotate by -30

# Reserve more space below the plot
set bmargin 6

# Place caption *below* the x-axis using screen coordinates
set label 1 "Leonardo Booster, CPU: Single-socket 32-core Intel Xeon Platinum 8358(2.60 Ghz) | GPU: NVIDIA A100 (64 GB HBM2e, NVLink 3.0, 200 GB/s)" \
    at screen 0.02, screen 0.07 front font "Arial,10"


plot 'timing.dat' using 2:xtic(1) title '1MPI rank', \
     '' using 3 title '2MPI ranks', \
     '' using 4 title '4MPI ranks', \
     '' using 5 title '8MPI ranks', \
     '' using 6 title '16MPI ranks'

