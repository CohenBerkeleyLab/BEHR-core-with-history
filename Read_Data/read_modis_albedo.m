function [ data ] = read_modis_albedo( modis_directory, date_in, data, varargin )
%UNTITLED6 Summary of this function goes here
%   Detailed explanation goes here

% Important references for MODIS BRDF v006 product:
%   V006 User Guide: https://www.umb.edu/spectralmass/terra_aqua_modis/v006
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% INPUT VALIDATION %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

E = JLLErrors;
p = inputParser;
p.addParameter('DEBUG_LEVEL', 0);
p.addParameter('LoncornField', 'FoV75CornerLongitude');
p.addParameter('LatcornField', 'FoV75CornerLatitude');
p.parse(varargin{:});
pout = p.Results;

DEBUG_LEVEL = pout.DEBUG_LEVEL;
loncorn_field = pout.LoncornField;
latcorn_field = pout.LatcornField;

if ~ischar(modis_directory)
    E.badinput('MODIS_DIRECTORY must be a string')
elseif ~exist(modis_directory, 'dir')
    E.badinput('MODIS_DIRECTORY is not a directory')
end


if isnumeric(date_in)
    if ~isscalar(date_in)
        E.badinput('If given as a number, DATE_IN must be scalar')
    end
elseif ischar(date_in)
    try
        datenum(date_in);
    catch err
        if strcmp(err.identifier, 'MATLAB:datenum:ConvertDateString')
            E.badinput('DATE_IN could not be recognized as a valid format for a date string')
        else
            rethrow(err)
        end
    end
else
    E.badinput('DATE_IN must be a string or number')
end

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% MAIN FUNCTION %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

this_year = sprintf('%04d', year(date_in));
alb_dir = fullfile(modis_directory, this_year);
julian_day = modis_date_to_day(date_in);

% As of version 6 of MCD43C1, a 16-day average is produced every day, so
% unlike version 5 of MCD43C3 where we had to look forward and back in time
% from the current date, we should be able to just pick the file for this
% day.

mcd_filename = sprintf('MCD43C1.A%04d%03d*.hdf', year(date_in), julian_day);
alb_filename = fullfile(alb_dir, mcd_filename);
alb_files = dir(alb_filename);
if numel(alb_files) < 1
    E.filenotfound('MODIS BRDF file matching pattern %s.', alb_filename);
elseif numel(alb_files) > 1
    E.toomanyfiles('Multiple MODIS BRDF files found matching pattern %s.', alb_filename);
end 

mcd43_info = hdfinfo(fullfile(alb_dir,alb_files(1).name));
band3_iso = hdfreadmodis(mcd43_info.Filename, hdfdsetname(mcd43_info,1,1,'BRDF_Albedo_Parameter1_Band3'));
band3_vol = hdfreadmodis(mcd43_info.Filename, hdfdsetname(mcd43_info,1,1,'BRDF_Albedo_Parameter2_Band3'));
band3_geo = hdfreadmodis(mcd43_info.Filename, hdfdsetname(mcd43_info,1,1,'BRDF_Albedo_Parameter3_Band3'));

band3_iso = flipud(double(band3_iso));
band3_vol = flipud(double(band3_vol));
band3_geo = flipud(double(band3_geo));

%MODIS albedo is given in 0.05 degree cells and a single file covers the
%full globe, so figure out the lat/lon of the middle of the grid cells as:
band3_lat=-90+0.05/2:0.05:90-0.05/2; band3_lats=band3_lat'; band3_lats=repmat(band3_lats,1,7200);
band3_lon=-180+0.05/2:0.05:180-0.05/2; band3_lons=repmat(band3_lon,3600,1);

%To speed up processing, restrict the MODIS albedo data to
%only the area we need to worry about.  This will
%significantly speed up the search for albedo values within
%each pixel.
loncorn = data.(loncorn_field)(:);
latcorn = data.(latcorn_field)(:);
loncorn(loncorn==0) = [];
latcorn(latcorn==0) = [];
lon_min = floor(min(loncorn));
lon_max = ceil(max(loncorn));
lat_min = floor(min(latcorn));
lat_max = ceil(max(latcorn));

in_lats = find(band3_lat>=lat_min & band3_lat<=lat_max);
in_lons = find(band3_lon>=lon_min & band3_lon<=lon_max);

band3_iso = band3_iso(in_lats,in_lons); 
band3_vol = band3_vol(in_lats,in_lons);
band3_geo = band3_geo(in_lats,in_lons);

band3_lats=band3_lats(in_lats,in_lons);
band3_lons=band3_lons(in_lats,in_lons);

s=size(data.Latitude);
c=numel(data.Latitude);
MODISAlbedo=nan(s);

%Now actually average the MODIS albedo for each OMI pixel
if DEBUG_LEVEL > 0; disp(' Averaging MODIS albedo to OMI pixels'); end
for k=1:c;
    if DEBUG_LEVEL > 2; tic; end
    
    xall=[data.(loncorn_field)(:,k); data.(loncorn_field)(1,k)];
    yall=[data.(latcorn_field)(:,k); data.(latcorn_field)(1,k)];
    
    % If there is an invalid corner coordinate, skip because we cannot
    % be sure the correct polygon will be used.
    if any(isnan(xall)) || any(isnan(yall))
        continue
    end
    
    % should be able to speed this up by first restricting based on a
    % single lat and lon vector
    xx_alb = inpolygon(band3_lats,band3_lons,yall,xall);
    
    band3_vals = modis_brdf_alb(band3_iso(xx_alb), band3_vol(xx_alb), band3_geo(xx_alb), data.SolarZenithAngle(k), data.ViewingZenithAngle(k), data.RelativeAzimuthAngle(k));
    band3_avg = nanmean(band3_vals(band3_vals>0));
    
    %put in ocean surface albedo from LUT
    if isnan(band3_avg)==1;
        sza_vec = [5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 89];
        alb_vec = [0.038 0.038 0.039 0.039 0.040 0.042 0.044 0.046 0.051 0.058 0.068 0.082 0.101 0.125 0.149 0.158 0.123 0.073];
        band3_avg = interp1(sza_vec, alb_vec, data.SolarZenithAngle(k));
    end
    
    MODISAlbedo(k) = band3_avg;
    if DEBUG_LEVEL > 2; telap = toc; fprintf(' Time for MODIS alb --> pixel %u/%u = %g sec \n',k,c,telap); end
end

data.MODISAlbedo = MODISAlbedo;
data.MODISAlbedoFile = mcd43_info.Filename;

end
