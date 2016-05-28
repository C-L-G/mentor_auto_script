## +++++++++++++++++++++++++
## 2016-05-28 20:29:15 +0800 
## +++++++++++++++++++++++++
proc ensure_lib { lib } { if ![file isdirectory $lib] { vlib $lib } }
##=============packages==================
## pkg_file: 1 
ensure_lib		./prj_pkg/
vmap prj_pkg ./prj_pkg/


##=============ROOT==================
## /home/young/work/ruby/cordic root_file: 1 
##---------------------------------------
##=============sqrt==================
## sqrt file: 4 
ensure_lib		./prj_sqrt/
vmap prj_sqrt ./prj_sqrt/

vlog -incr /home/young/work/ruby/cordic/sqrt/cordic_sqrt.v -L prj_pkg -work prj_sqrt 
##=============XY-to-angle==================
## XY-to-angle file: 4 
ensure_lib		./prj_XY-to-angle/
vmap prj_XY-to-angle ./prj_XY-to-angle/

##=============sin-cos==================
## sin-cos file: 6 
ensure_lib		./prj_sin-cos/
vmap prj_sin-cos ./prj_sin-cos/


##=============ROOT==================
## /home/young/work/ruby/general-cordic-rotaion root_file: 8 
##---------------------------------------
##=============test_angle_to_XY==================
## test_angle_to_XY file: 2 
ensure_lib		./prj_test_angle_to_XY/
vmap prj_test_angle_to_XY ./prj_test_angle_to_XY/


##=============ROOT==================
## /home/young/work/ruby/file-class-package root_file: 3 
##---------------------------------------

##==========================
###   vsim script
vsim -L prj_pkg -L prj_sqrt-L prj_XY-to-angle-L prj_sin-cos-L prj_test_angle_to_XY  -L 220model_ver -L altera_lnsim_ver -L altera_mf_ver -L altera_ver -L cycloneive_ver -L cycloneiii_ver -novopt  work.image_file_package_tb  prj_XY-to-angle.X_Y_to_angle_tb 
