#!/bin/bash
#: wrf model automation script

### 脚本所在目录
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
#########################################
#                路径              
#########################################
GFS_DIR=/thfs1/home/qx_hyt/hpp/data/GFS/2023051412/
WPS_DIR=/thfs1/home/qx_hyt/hpp/model/PWRF/WPS-4.4/ 
WRF_DIR=/thfs1/home/qx_hyt/hpp/model/PWRF/WRF-4.3.3/    
WPS_GEOG=/thfs1/home/qx_hyt/hpp/model/PWRF/WPS-4.4/WPS_GEOG                  
#########################################

#             Running wps  

#########################################
cd $WPS_DIR
### 新建文件夹存放 wps 输出
rm -rf wps_output
rm Vtable
mkdir wps_output
cd wps_output
mkdir geogrid 
mkdir ungrib 
mkdir metgrid 
cd ..

#########################################
#           Edit namelist.wps              
#########################################
echo "请输入一个开始时间,格式YYYY-MM-dd"  
read start_time
echo "请输入一个结束时间,格式YYYY-MM-dd"  
read end_time
start=$start_time
end=$end_time

echo "&share
 wrf_core = 'ARW',
 max_dom = 1,
 start_date = '${start}_12:00:00', 
 end_date   = '${end}_12:00:00', 
 interval_seconds = 10800,
 io_form_geogrid = 2,
 debug_level = 0,
 opt_output_from_geogrid_path = ${WPS_DIR}wps_output/geogrid',
/

&geogrid
 parent_id         =   1,   1,
 parent_grid_ratio =   1,   3,
 i_parent_start    =   1,  53,
 j_parent_start    =   1,  25,
 e_we              =  225, 220,
 e_sn              =  225, 214,
 geog_data_res = 'default','default',
 dx = 30000,
 dy = 30000,
 map_proj = 'polar',
 ref_lat   =  90.00,
 ref_lon   = 120.00,
 truelat1  =  30.0,
 truelat2  =  60.0,
 stand_lon = 120.0,
 geog_data_path = $WPS_GEOG
/

&ungrib
 out_format = 'WPS',
 prefix = 'FILE',
 prefix = ${WPS_DIR}wps_output/ungrib/FILE'
/

&metgrid
 fg_name = 'FILE'
 io_form_metgrid = 2,
 opt_output_from_metgrid_path = '${WPS_DIR}wps_output/metgrid'
/
" > namelist.wps
### 运行 wps
./link_grib.csh ${GFS_DIR}gfs* 
ln -sf ungrib/Variable_Tables/Vtable.GFS Vtable
yhbatch -p thcp1 geogrid.sh
echo "geogrid end"
yhbatch -p thcp1 ungrib.sh
echo "ungrib end"
yhbatch -p thcp1 metgrid.sh
echo "metgrid end"

#########################################

#             Running wrf  

#########################################
cd $WRF_DIR
### 新建文件夹存放 wrf 输出
if [ ! -d wrf_output  ];then
  rm -rf wrf_output
else
  echo dir no exist
fi
mkdir wrf_output

# year=$(date   +"%Y")
# month=$(date  +"%m")
# today=$(date  +"%d")

# tyear=$(date  --date="2 days" +"%Y")
# tmonth=$(date --date="2 days" +"%m")
# tday=$(date   --date="2 days" +"%d")
#########################################
#           Edit namelist.input              
#########################################
echo "&time_control
 run_days                            = 0,
 run_hours                           = 48,
 run_minutes                         = 0,
 run_seconds                         = 0,
 start_year                          = $start_time,
 start_month                         = $month,
 start_day                           = $today,
 start_hour                          = 12,
 start_minute                        = 00,
 start_second                        = 00,
 end_year                            = $tyear,
 end_month                           = $tmonth,
 end_day                             = $tday,
 end_hour                            = 12,
 end_minute                          = 00,
 end_second                          = 00,
  interval_seconds                    = 10800
 input_from_file                     = .true.,.true.,
 history_interval                    = 60,  60,
 frames_per_outfile                  = 1, 1,
 restart                             = .false.,
 restart_interval                    = 7200,
 io_form_history                     = 2
 io_form_restart                     = 2
 io_form_input                       = 2
 io_form_boundary                    = 2
 debug_level                         = 0
 history_outname = '/thfs1/home/qx_hyt/hpp/output_data/PWRF/WRF4.3/20230514/wrfout/wrfout_d<domain>_<date>',
 /

 &domains
 time_step                           = 30,
 time_step_fract_num                 = 0,
 time_step_fract_den                 = 1,
 max_dom                             = 1,
 e_we                                = 225,    220,
 e_sn                                = 225,    214,
 e_vert                              = 45,     45,
 dzstretch_s                         = 1.1
 p_top_requested                     = 5000,
 num_metgrid_levels                  = 34,
 num_metgrid_soil_levels             = 4,
 dx                                  = 30000,
 dy                                  = 30000,
 grid_id                             = 1,     2,
 parent_id                           = 0,     1,
 i_parent_start                      = 1,     53,
 j_parent_start                      = 1,     25,
 parent_grid_ratio                   = 1,     3,
 parent_time_step_ratio              = 1,     3,
 feedback                            = 1,
 smooth_option                       = 0
 /

 &physics
 progn                    = 0,     0,
 mp_physics                          =  26,    26,  26,
 cu_physics                          =  1,     1,   0,
 cu_rad_feedback                     = .true.,.true.,.false.,
 ra_lw_physics                       =  4,     4,   4,
 ra_sw_physics                       =  4,     4,   4,
 bl_pbl_physics                      =  1,     1,   1,
 sf_sfclay_physics                   =  1,     1,   1,
 sf_surface_physics                  =  0,     2,   2,
 radt                                =  30,    30,  30,
 bldt                                =  0,     0,   0,
 cudt                                =  5,     5,   0,
 icloud                              =  1,
 do_radar_ref                        =  1,
 isfflx                   = 1,
 ifsnow                   = 0,
 icloud                   = 1,
 surface_input_source     = 1,
 num_soil_layers          = 6, 
 sf_urban_physics         = 0,        0,        0,
 aercu_opt                = 0,
 maxiens                  = 1,
 maxens                   = 3,
 maxens2                  = 3,
 maxens3                  = 16,
 ensdim                   = 144,
 num_land_cat             = 21,      
 /

 &fdda
 /

 &dynamics
 hybrid_opt                          = 2, 
 w_damping                           = 0,
 diff_opt                            = 2,      2,
 km_opt                              = 4,      4,
 diff_6th_opt                        = 0,      0,
 diff_6th_factor                     = 0.12,   0.12,
 base_temp                           = 290.
 damp_opt                            = 3,
 zdamp                               = 5000.,  5000.,
 dampcoef                            = 0.2,    0.2,
 khdif                               = 0,      0,
 kvdif                               = 0,      0,
 non_hydrostatic                     = .true., .true.,
 moist_adv_opt                       = 1,      1,
 scalar_adv_opt                      = 1,      1,
 gwd_opt                             = 1,      0,
 /

 &bdy_control
 spec_bdy_width                      = 5,
 specified                           = .true.
 /

 &grib2
 /

 &namelist_quilt
 nio_tasks_per_group = 0,
 nio_groups = 1,
 /
" >namelist.input