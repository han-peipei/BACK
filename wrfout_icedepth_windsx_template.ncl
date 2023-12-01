load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"


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
   newday = ccyy*10000 + mm*100 + dd
   return(newday)

end 



undef("advance_cymdh")
function advance_cymdh(ccyy0, mm0, dd0, hh0, dh:integer)
local ccyy,mm,dd,hh
begin

   ccyy  = stringtointeger(ccyy0)
   mm    = stringtointeger(mm0)
   dd    = stringtointeger(dd0)
   hh    = stringtointeger(hh0)
   hh    = hh + dh
   
   newday = ccyy*10000 + mm*100 + dd
   do while (hh .lt. 0)
      hh = hh + 24
      newday = change_date( ccyy, mm, dd, -1 )
   end do
   do while (hh .gt. 23)
      hh = hh - 24
      newday = change_date( ccyy, mm, dd, 1 )
   end do
   if (mm.le.9) then
   newdatestr = ccyy+"-0"+mm+"-"+dd+"-"+hh+":00"
   else
   newdatestr = ccyy+"-"+mm+"-"+dd+"-"+hh+":00"
   end if
   return(newdatestr)
   ;delete([/ccyy,mm,dd,hh/])

end


undef("get_time")
function get_time(filename:string,return_flag:string)
begin

   dtime_map = (/11,4,1,2,1,2,1,8/)
   tst_dtime = str_split_by_length(filename, dtime_map)
   yyyy      = tst_dtime(1)
   mm        = tst_dtime(3)
   dd        = tst_dtime(5)
   hh0       = tst_dtime(7)
   hh1       = str_split_by_length(hh0,2)
   hh        = hh1(0)
   dh        = 8 ;BJT=UTC+8
   if (return_flag.eq."init") then
      init_time = yyyy+"-"+mm+"-"+dd+"-"+hh+":00"
      return(init_time)
   end if
   if (return_flag.eq."valid") then
      valid_time= advance_cymdh(yyyy,mm,dd,hh,dh)
      return(valid_time)
   end if

end


undef("change_units")
function change_units(var:numeric)
begin
varf=var*1000.
varf@units="g/kg"
copy_VarMeta(var,varf)
return(varf)
end


undef("get_vis")
function get_vis(filename:string,it:integer)
begin

   a=addfile(filename,it)

   beta_cw     =  change_units(wrf_user_getvar(a,"QCLOUD",it))
   beta_iw     =  change_units(wrf_user_getvar(a,"QICE",it))
   beta_snow   =  change_units(wrf_user_getvar(a,"QRAIN",it))
   beta_rain   =  change_units(wrf_user_getvar(a,"QSNOW",it))

   nl=1

   beta            =  beta_cw(nl,:,:)+beta_iw(nl,:,:)+beta_snow(nl,:,:)+beta_rain(nl,:,:)
   beta@_FillValue =  -99999
   beta            =  where(beta.le.0.00001,beta@_FillValue,beta)

   nlat = 224
   nlon = 224
   vis  = new((/nlat,nlon/),float,-99999)
 
   vis = -log(0.02/beta) 
   vis = where(vis.le.0,vis@_FillValue,vis)
   
   return(vis)

end









begin

; dir      = "/thfs1/home/qx_hyt/PWRF/test/"
; filename = "wrfout_d01_2023-05-14_12:00:00"
dir      = "DIR"
;filename = "met_em.d01.2023-05-14_15:00:00.nc"
filename = "FILENAME"

a        = addfile(dir+filename, "r")

  it   = 1
  ice  = wrf_user_getvar(a,"ICEDEPTH",it)    ; 3D temperature
  u    = wrf_user_getvar(a,"U10",it)          ; 3D U at mass points
  v    = wrf_user_getvar(a,"V10",it)          ; 3D V at mass points

  vis  = get_vis(dir+filename,it)

  ;nl   = 0
  ;u10  = u(nl,:,:)
  ;v10  = v(nl,:,:)

  ;u10  = u10*1.94386                    ; Convert wind into knots
  ;v10  = v10*1.94386

  ;u10x = wrf_user_unstagger( u10, u10@stagger)
  ;v10x = wrf_user_unstagger( v10, v10@stagger)

  xlat = wrf_user_getvar(a,"XLAT",it)
  xlon = wrf_user_getvar(a,"XLONG",it)
  
  ice@lat2d   = xlat
  ice@lon2d   = xlon
  u@lat2d     = xlat
  u@lon2d     = xlon  
  v@lat2d     = xlat
  v@lon2d     = xlon
  ;u10@lat2d   = xlat
  ;u10@lon2d   = xlon
  ;v10@lat2d   = xlat
  ;v10@lon2d   = xlon
  ;u10x@lat2d   = xlat
  ;u10x@lon2d   = xlon
  ;v10x@lat2d   = xlat
  ;v10x@lon2d   = xlon

  vis@lat2d   = xlat
  vis@lon2d   = xlon

;   printVarSummary(u)

  init_time  =  get_time(filename,"init")
  valid_time =  get_time(filename,"valid")

  ;---Change the metadata
  ice@units        = "m"
  ;u10@units        = "kts"
  ;v10@units        = "kts"

  wks = gsn_open_wks("png","OUTPUT")

;plot = new(2,graphic)

  ;---Set common resources
    ice_res                 = True
    ice_res@gsnLeftString   = "color: Ice Depth (unit:m) ~C~vector:<U10,V10> (unit:m/s)"
    ice_res@gsnRightString  = "Initial:      "+init_time+"~C~"+"Forecast: "+valid_time
    ice_res@tiMainString    = "PWRF"

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
    ice_res@lbLabelStrings    = (/0.4,0.8,1.2,1.6,2.0,2.4,2.8,3.2,3.6,4.0,4.4,4.8,5.2/)

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

    ice@_FillValue=9.81344e+36
    ice=where(ice.gt.10.,ice@_FillValue,ice)

    plot1 = gsn_csm_vector_scalar_map_polar(wks,u,v,ice,ice_res)

    res = True
    res@gsnPolar   = "NH"
    res@mpMinLatF  = 50
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
    res@gsnRightString    = "Initial:      "+init_time+"~C~"+"Forecast: "+valid_time
    res@tiMainString      = "PWRF"

    copy_VarMeta(u,vis)
    vis@_FillValue=-99999
    
    plot2  = gsn_csm_contour_map_polar(wks,vis,res)


/;
  
  ;---ICE filled contour plot
    ice_res                   = res                         
    ice_res@cnFillOn          = True   
    ice_res@lbTitleOn         = True
    ice_res@lbTitleString     = " "
    ice_res@lbTitlePosition   = "bottom"              ; title position
    ice_res@lbTitleFontHeightF= .015 
    ice_res@lbTitleDirection  = "Across"
    ice_res@lbLabelFont       = "Helvetica-Bold"
    ice_res@lbLabelPosition   = "Center"
    ice_res@lbLabelAlignment  = "BoxCenters";"InteriorEdges";"ExternalEdges";"BoxCenters"
    ice_res@lbLabelStrings    = (/0.4,0.8,1.2,1.6,2.0,2.4,2.8,3.2,3.6,4.0,4.4,4.8,5.2/) 
    ice_res@Footer            = False     
    ice_res@InitTime          = False

    ice_res@lbOrientation     = "vertical"
    ice_res@pmLabelBarSide    = "right"
    ice_res@pmLabelBarHeightF = 0.65

    ice0@_FillValue=9.81344e+36
    ice0=where(ice0.gt.10.,ice0@_FillValue,ice0)
    

    contour_ice = wrf_contour(a,wks,ice0,ice_res)
  
  ;---Wind vector plot
    vec_res            = res         
    vec_res@FieldTitle = "Vector: <U10,V10>" ;"TJPWRF--"+time_string   ;"2023-10-27 08:00 +003H (2711)"       ; overwrite Field Title
    vec_res@NumVectors = 45           ; density of wind barbs
    vec_res@Footer     = False
    vec_res@InitTime   = False
    ;vec_res@InitTimeLabel = init_time
    vec_res@MainTitle  = "PWRF"
    vector = wrf_vector(a,wks,u10x,v10x,vec_res)
    
  ;---Overlay plots on map and draw.
    map_res = True
    map_res@mpDataSetName               = "Earth..4"
    map_res@mpGeophysicalLineThicknessF = 5.
    map_res@mpFillOn                    = True
    map_res@mpFillAreaSpecifiers        = (/"water",       "land" /)
    map_res@mpSpecifiedFillColors       = (/"transparent","white"/)
    ov = wrf_map_overlays(a,wks,(/contour_ice,vector/),True,map_res)

;/

end 
