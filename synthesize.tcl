# Original synthesis settings, with project output local to this repository.
set example_dir [file dirname [file normalize [info script]]]
set project_dir [file normalize [file join $example_dir build hls_project]]
open_project -reset $project_dir
add_files [file join $example_dir source/array_madd.c]
set_top array_madd_top
open_solution -reset solution
set_part {xc7z020clg484-1}
create_clock -period 4
csynth_design
exit
