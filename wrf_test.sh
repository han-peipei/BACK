#!/bin/bash
WRF_DIR=/thfs1/home/qx_hyt/hpp/model/PWRF/WRF-4.3.3/run/ 
WPS_DIR=/thfs1/home/qx_hyt/hpp/model/PWRF/WPS-4.4/ 
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
start_time="2023-05-14_12:00:00"
end_time="2023-05-18_00:00:00"
run_hours=84
cd $WRF_DIR
### 新建文件夹存放 wrf 输出
if [ -d wrf_output  ];then
  rm -rf wrf_output
else
  echo wrf_output no exist
fi

mkdir wrf_output
cd wrf_output 
cd ..
declare -A patterns
patterns["RUN_HOURS"]=$run_hours
patterns["START_YEAR_1"]=${start_time:0:4}
patterns["START_MONTH_1"]=${start_time:5:2}
patterns["START_DAY_1"]=${start_time:8:2}
patterns["START_HOUR_1"]=${start_time:11:2}
patterns["END_YEAR_1"]=${end_time:0:4}
patterns["END_MONTH_1"]=${end_time:5:2}
patterns["END_DAY_1"]=${end_time:8:2}
patterns["END_HOUR_1"]=${end_time:11:2}
patterns["OUTNAME"]="${WRF_DIR}wrf_output/wrfout_d<domain>_<date>"

sed_cmd="s|<pattern_to_replace_1>|<replacement_text_1>|g"
for key in "${!patterns[@]}"; do
  old_pattern="$key"
  new_pattern="${patterns[$key]}"
  sed_cmd+=";s|$old_pattern|$new_pattern|g"
done
input_file=${BASE_DIR}/namelist_template.input
output_file="namelist.input"
sed "$sed_cmd" < "$input_file" > "$output_file"

ln -sf ${WPS_DIR}wps_output/metgrid/met* .

cat > real.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 1 -p thcp1 ./real.exe >&real.out
EOF
chmod a+x real.sh
yhbatch -p thcp1 real.sh  >& jobID_real
pid_real=$(awk '{print $4}' jobID_real)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_real" | awk '{print $1}')
    if [ "$job_status" == "$pid_real" ]; then
        sleep 60  
    else
        break 
    fi
done

cat > wrf.sh <<EOF
#!/bin/bash
yhrun -n 56 -p thcp1 ./wrf.exe >&wrf.out
EOF
chmod a+x wrf.sh
yhbatch -p thcp1 wrf.sh  >& jobID_wrf
pid_wrf=$(awk '{print $4}' jobID_wrf)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_wrf" | awk '{print $1}')
    if [ "$job_status" == "$pid_wrf" ]; then
        sleep 60  
    else
        break 
    fi
done