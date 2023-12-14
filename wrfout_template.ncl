load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"



undef("alignment_format2")
function alignment_format2(yyyymmdd,hh)
begin

hh0 = tointeger(hh)

if (hh0.le.9) then
hhx = "0"+tostring(hh0)
end if
datestring=tostring(yyyymmdd)+hhx
return(datestring)
end



undef("alignment_format3")
function alignment_format3(yyyy,mm,dd)
begin
yyyy0 = tointeger(yyyy)
mm0x  = tointeger(mm)
dd0x  = tointeger(dd)
if (mm0x.le.9) then 
mm0x := "0"+tostring(mm0x)
end if 
if (dd0x.le.9) then
dd0x := "0"+tostring(dd0x)
end if 
datestring=tostring(yyyy0)+mm0x+dd0x
return(datestring)
end



undef("alignment_format4")
function alignment_format4(yyyy,mm,dd,hh)
begin
yyyy0 = tointeger(yyyy)
mm0   = tointeger(mm)
dd0   = tointeger(dd)
hh0   = tointeger(hh)
if (mm0.le.9) then 
mm0 := "0"+tostring(mm0)
end if 
if (dd0.le.9) then
dd0 := "0"+tostring(dd0)
end if 
if (hh0.le.9) then 
hh0 := "0"+tostring(hh0)
end if 
datestring=tostring(yyyy0)+mm0+dd0+hh0
return(datestring)
end



undef("change_date")
function change_date(ccyy:integer, mm:integer, dd:integer, delta:integer)
local mmday, newday
begin

   mmday = (/31,28,31,30,31,30,31,31,30,31,30,31/)
   if ( isleapyear(ccyy) ) then
      mmday(1) = 29
   end if
   dd = dd + delta
   if ( dd .eq. 0 ) then
      mm = mm - 1
      if ( mm .eq. 0 ) then
         mm = 12
         ccyy = ccyy - 1
      end if
      dd = mmday(mm-1)
   else
      if ( dd .gt. mmday(mm-1) ) then
         dd = 1
         mm = mm + 1
         if ( mm .gt. 12 ) then
            mm = 1
            ccyy = ccyy + 1
         end if
      end if
   end if
   ;newday = ccyy*10000 + mm*100 + dd
   newday  = alignment_format3(ccyy,mm,dd)
   return(newday)
   delete([/mmday,newday/])

end



undef("advance_cymdh")
function advance_cymdh(currentdatestr:string, dh:integer)
local ccyy, mm, dd, hh, newday, newdatestr
begin

   currentdate = stringtochar(currentdatestr)
   ccyy = stringtointeger((/currentdate(0:3)/))
   mm   = stringtointeger((/currentdate(4:5)/))
   dd   = stringtointeger((/currentdate(6:7)/))
   hh   = stringtointeger((/currentdate(8:9)/))
   hh   = hh + dh
   ;newday = ccyy*10000 + mm*100 + dd
   newday = alignment_format4(ccyy,mm,dd,hh)
   do while (hh .lt. 0)
      hh = hh + 24
      newday := change_date(ccyy, mm, dd, -1)
      newday := alignment_format2(newday,hh)
   end do
   do while (hh .gt. 23)
      hh = hh - 24
      newday := change_date(ccyy, mm, dd, 1)
      newday := alignment_format2(newday,hh)
   end do
   ;   newdate = newday*100 + hh
   ;   newdatestr = sprinti("%0.8i",newday) + sprinti("%0.2i",hh)
   return(newday)

end



undef("get_current_cst")
function get_current_cst(filename)
begin

dtime_map = (/11,4,1,2,1,2,1,8/)
   tst_dtime = str_split_by_length(filename, dtime_map)
   yyyy      = tst_dtime(1)
   mm        = tst_dtime(3)
   dd        = tst_dtime(5)
   hhx0      = tst_dtime(7)
   hhx       = str_split_by_length(hhx0,2)
   hh        = tostring(tointeger(hhx(0))+8)

current_time = yyyy+mm+dd+hh
return(current_time)
   
end 



undef("get_current_utc")
function get_current_utc(filename)
begin

dtime_map = (/11,4,1,2,1,2,1,8/)
   tst_dtime = str_split_by_length(filename, dtime_map)
   yyyy      = tst_dtime(1)
   mm        = tst_dtime(3)
   dd        = tst_dtime(5)
   hhx0      = tst_dtime(7)
   hhx       = str_split_by_length(hhx0,2)
   hh        = tostring(tointeger(hhx(0)))

current_time = yyyy+mm+dd+hh
return(current_time)

end



undef("get_cst_time")
function get_cst_time(current_time,filename)   ;2023051412
begin

   dh         = 1  
   cst_time0  = get_current_cst(filename)
   if (cst_time0.eq.current_time) then
   return(cst_time0)
   else
   ;cst_time   = advance_cymdh(current_time,dh)
   cst_time   = advance_cymdh(current_time,dh)
   return(cst_time)
   end if

end



undef("get_utc_time")
function get_utc_time(current_time,filename)   ;2023051412
begin

   dh         = 1
   utc_time0  = get_current_utc(filename)
   if (utc_time0.eq.current_time) then
   return(utc_time0)
   else
   ;cst_time   = advance_cymdh(current_time,dh)
   utc_time   = advance_cymdh(current_time,dh)
   return(utc_time)
   end if

end



undef("change_units")
function change_units(var:numeric)
local varf
begin

varf=var*1000.
varf@units="g/kg"
copy_VarMeta(var,varf)
return(varf)
delete(varf)

end



undef("get_vis")
function get_vis(beta_cw,beta_iw,beta_snow,beta_rain)
begin

   nl=1

   beta            =  (/beta_cw(nl,:,:)+beta_iw(nl,:,:)+beta_snow(nl,:,:)+beta_rain(nl,:,:)/)
   beta@_FillValue =  -99999
   beta            =  (/where(beta.le.0.0001,beta@_FillValue,beta)/)
   nlat = 224
   nlon = 224
   vis0 = new((/nlat,nlon/),float,-99999)
 
   vis0 = (/-log(0.02/beta)/)
   vis0 = (/where(vis0.le.0,vis0@_FillValue,vis0)/)
   
   return(vis0)
   delete([/beta_cw,beta_iw,beta_snow,beta_rain/])

end









begin

dir      = "DIR"
filename = "FILENAME"
nt        = 85

initial_time = get_current_utc(filename)
current_cst0 = get_current_cst(filename)
current_utc0 = get_current_utc(filename)

do it=0,nt-1

if (it.eq.0) then
current_cst = current_cst0
current_utc = current_utc0
end if

time_step  =  1*it
utc_time   =  get_utc_time(current_utc,filename)
cst_time   =  get_cst_time(current_cst,filename)

print(current_utc)

a      = addfile(dir+filename, "r")

  ice  = wrf_user_getvar(a,"ICEDEPTH",it)     ; 3D temperature
  u    = wrf_user_getvar(a,"U10",it)          ; 3D U at mass points
  v    = wrf_user_getvar(a,"V10",it)          ; 3D V at mass points

  beta_cw     =  (/change_units(wrf_user_getvar(a,"QCLOUD",it))/)
  beta_iw     =  (/change_units(wrf_user_getvar(a,"QICE"  ,it))/)
  beta_snow   =  (/change_units(wrf_user_getvar(a,"QRAIN" ,it))/)
  beta_rain   =  (/change_units(wrf_user_getvar(a,"QSNOW" ,it))/)

  vis  = get_vis(beta_cw,beta_iw,beta_snow,beta_rain)
  xlat = wrf_user_getvar(a,"XLAT",it)
  xlon = wrf_user_getvar(a,"XLONG",it)
  
  ice@lat2d   = xlat
  ice@lon2d   = xlon
  u@lat2d     = xlat
  u@lon2d     = xlon  
  v@lat2d     = xlat
  v@lon2d     = xlon
  vis@lat2d   = xlat
  vis@lon2d   = xlon

  ;---Change the metadata
  ice@units  = "m"

wks1 = gsn_open_wks("png","OUTPUT_ICEDEPTH"+current_cst)
wks2 = gsn_open_wks("png","OUTPUT_visibility"+current_cst)

  ;---Set common resources
    ice_res                 = True
    ice_res@gsnLeftString   = "color:   Ice Depth (unit:m) ~C~vector: <U10,V10> (unit:m/s)"
    ice_res@gsnRightString  = "Init:     "+initial_time+" (UTC)"+"~C~"+"Valid:  "+current_utc+" (UTC)"+"~C~"+"           "+current_cst+" (BJT)"
    ice_res@tiMainString    = "PWRF "+time_step+" h forecast: Arctic sea ice depth and 10m wind fields"

    ice_res@cnFillOn              = True  
    ice_res@gsnSpreadColorEnd     = -3
    ice_res@gsnScalarContour      = True              ; vectors over scalars
   
    ice_res@lbTitleOn         = True
    ice_res@lbTitleString     = " "
    ice_res@lbTitlePosition   = "bottom"              ; title position
    ice_res@lbTitleFontHeightF= .015
    ice_res@lbTitleDirection  = "Across"
    ice_res@lbLabelFont       = "Helvetica-Bold"
    ice_res@lbLabelPosition   = "Center"
    ice_res@lbLabelAlignment  = "BoxCenters";"InteriorEdges";"ExternalEdges";"BoxCenters"
    ice_res@lbLabelStrings    = (/0.4,0.8,1.2,1.6,2.0,2.4,2.8,3.2,3.6,4.0,4.4,4.8,5.2,5.6,6.0,6.4,6.8,7.2/)

    ice_res@lbOrientation     = "vertical"
    ice_res@pmLabelBarSide    = "right"
    ice_res@pmLabelBarHeightF = 0.65

    ice_res@vcRefMagnitudeF       = 20.0              ; vec magnitude
    ice_res@vcRefLengthF          = 0.02              ; size of ref vector
    ice_res@vcLineArrowColor      = "black"           ; white vectors
    ice_res@vcMinDistanceF        = 0.02              ; thins arrows near pole  
    ice_res@vcGlyphStyle          = "WindBarb"        ; turns on curly vectors
    ice_res@vcWindBarbScaleFactorF= 2.5

    ice_res@vcRefAnnoArrowLineColor   = "black"       ; black ref vector
    ice_res@vcRefAnnoArrowUseVecColor = False

    ice_res@gsnPolar   = "NH" 
    ice_res@mpMinLatF  = 50
    ice_res@mpCenterLonF = 90

    ice@_FillValue=9.81344e+36
    ice=where(ice.gt.10.,ice@_FillValue,ice)

    plot1 = gsn_csm_vector_scalar_map_polar(wks1,u,v,ice,ice_res)

    res = True
    res@gsnPolar   = "NH"
    res@mpMinLatF  = 50
    res@mpCenterLonF = 90
    res@cnFillOn   = True
    res@cnConstFEnableFill=True 
 
    res@cnLevelSelectionMode = "ExplicitLevels"   ; set explicit contour levels
    res@cnLevels             = (/0.05,0.5,1,2,10/); set levels
    res@cnLinesOn            = False    

    res@lbTitleOn         = True
    res@lbTitleString     = " "
    res@lbTitlePosition   = "bottom"              ; title position
    res@lbTitleFontHeightF= .015
    res@lbTitleDirection  = "Across"
    res@lbLabelFont       = "Helvetica-Bold"
    res@lbLabelPosition   = "Center"
    res@lbLabelAlignment  = "BoxCenters";"InteriorEdges";"ExternalEdges";"BoxCenters"
    res@lbLabelStrings    = (/0.05,0.5,1,2,10,15/)

    res@lbOrientation     = "vertical"
    res@pmLabelBarSide    = "right"
    res@pmLabelBarHeightF = 0.65

    res@gsnLeftString     = "color: Visibility (unit:km)"
    res@gsnRightString    = "Init:     "+initial_time+" (UTC)"+"~C~"+"Valid:  "+current_utc+" (UTC)"+"~C~"+"           "+current_cst+" (BJT)"
    res@tiMainString      = "PWRF "+time_step+" h forecast: Arctic visibility"

    copy_VarMeta(u,vis)
    vis@_FillValue=-99999
    
    plot2 = gsn_csm_contour_map_polar(wks2,vis,res)

    cst_timex = stringtochar(cst_time)
    utc_timex = stringtochar(utc_time)
    
    yyyy = tostring(cst_timex(0:3))
    mm   = tostring(cst_timex(4:5))
    dd   = tostring(cst_timex(6:7))
    hh   = tointeger(tostring(cst_timex(8:9)))

    if (it.eq.0) then
    current_cst = yyyy+mm+dd+tostring(hh+1)
    else
    current_cst = cst_time
    end if 

    yyyy := tostring(utc_timex(0:3))
    mm   := tostring(utc_timex(4:5))
    dd   := tostring(utc_timex(6:7))
    hh   := tointeger(tostring(utc_timex(8:9)))

    if (it.eq.0) then
    current_utc = yyyy+mm+dd+tostring(hh+1)
    else
    current_utc = utc_time
    end if


delete([/plot1,plot2/])
end do

end 
