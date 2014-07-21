function OMI = hdf_quadrangle_BEHR(Data, maxx, minx, maxy, miny, lCoordLon, lCoordLat, Lon1, Lon2, Lon4, Lat1, Lat2, Lat4)

% hdf_quadrangle_general: Version of hdf_quadrangle_5km_new by Ashley
% Russell from 11/19/2009 updated as a function.
%
%  Requires functions exchange_coord, calcline, clip.
%
%   This function should not be called directly; it is intended to be
%   called only from add2grid_general, which prepares geographic data for
%   this function.  It oversamples satellite data, mapping pixel
%   information to a fixed grid of smaller pixels.  These grids are
%   returned as the structure "OMI" (so named because it was first written
%   for NO2 data from the OMI instrument onboard the Aura satellite).  The
%   structure can be used in the no2_column_map_2014 function to produce
%   maps.
%
%   Josh Laughner <joshlaugh5@gmail.com> 18 Jul 2014


% Prepare empty matrices to receive the information that will make up the
% oversampled grid.  Those expected to receive quality flags will be cell
% arrays instead.

BEHRColumnAmountNO2Trop=zeros(maxx,maxy);
Time=zeros(maxx,maxy);
ViewingZenithAngle=zeros(maxx,maxy);
SolarZenithAngle=zeros(maxx,maxy);
ViewingAzimuthAngle=zeros(maxx,maxy);
SolarAzimuthAngle=zeros(maxx,maxy);
CloudFraction=zeros(maxx,maxy);
CloudRadianceFraction=zeros(maxx,maxy);
ColumnAmountNO2=zeros(maxx,maxy);
SlantColumnAmountNO2=zeros(maxx,maxy);
TerrainHeight=zeros(maxx,maxy);
TerrainPressure=zeros(maxx,maxy);
TerrainReflectivity=zeros(maxx,maxy);
CloudPressure=zeros(maxx,maxy);
RelativeAzimuthAngle=zeros(maxx,maxy);
Latitude=zeros(maxx,maxy);
Longitude=zeros(maxx,maxy);
ColumnAmountNO2Trop=zeros(maxx,maxy);
GLOBETerpres=zeros(maxx,maxy);
MODISAlbedo=zeros(maxx,maxy);
BEHRAMFTrop=zeros(maxx,maxy);
MODISCloud=zeros(maxx,maxy);
Row=zeros(maxx,maxy);
Swath=zeros(maxx,maxy);
AMFTrop=zeros(maxx,maxy);
AMFStrat=zeros(maxx,maxy);
TropopausePressure=zeros(maxx,maxy);
Count = zeros(maxx, maxy);
Area = nan(maxx, maxy);
Areaweight = nan(maxx, maxy);

vcdQualityFlags=cell(maxx,maxy);
XTrackQualityFlags=cell(maxx,maxy);


%JLL 2-14-2014: Loads all the relevant fields from Data (the file
%loaded from reading the OMI_SP file)
% Time_i=Data(d).Time;
% ViewingZenithAngle_i=Data(d).ViewingZenithAngle;
% SolarZenithAngle_i=Data(d).SolarZenithAngle;
% ViewingAzimuthAngle_i=Data(d).ViewingAzimuthAngle;
% SolarAzimuthAngle_i=Data(d).SolarAzimuthAngle;
% CloudFraction_i=Data(d).CloudFraction;
% CloudRadianceFraction_i=Data(d).CloudRadianceFraction;
% ColumnAmountNO2_i=Data(d).ColumnAmountNO2;
% SlantColumnAmountNO2_i=Data(d).SlantColumnAmountNO2;
% ColumnAmountNO2Trop_i=Data(d).ColumnAmountNO2Trop;
% TerrainHeight_i=Data(d).TerrainHeight;
% TerrainPressure_i=Data(d).TerrainPressure;
% TerrainReflectivity_i=Data(d).TerrainReflectivity;
% CloudPressure_i=Data(d).CloudPressure;
% RelativeAzimuthAngle_i=Data(d).RelativeAzimuthAngle;
% Latitude_i=Data(d).Latitude;
% Longitude_i=Data(d).Longitude;
% GLOBETerpres_i=Data(d).GLOBETerpres;
% MODISAlbedo_i=Data(d).MODISAlbedo;
% BEHRAMFTrop_i=Data(d).BEHRAMFTrop;
% BEHRColumnAmountNO2Trop_i=Data(d).BEHRColumnAmountNO2Trop;
% MODISCloud_i=Data(d).MODISCloud;
% Row_i=Data(d).Row;
% Swath_i=Data(d).Swath;
% AMFTrop_i=Data(d).AMFTrop;
% AMFStrat_i=Data(d).AMFStrat;
% vcdQualityFlags_i=Data(d).vcdQualityFlags;
% XTrackQualityFlags_i=Data(d).XTrackQualityFlags;
% TropopausePressure_i=Data(d).TropopausePressure;
%
% Data.Count = zeros(size(Data.Latitude));
% Data.Area = nan(size(Data.Latitude));
% Data.Areaweight = nan(size(Data.Latitude));


Dimensions = size(Data.BEHRColumnAmountNO2Trop);
for x=1:1:Dimensions(1)*Dimensions(2); %JLL 18 Mar 2014: Loop over each NO2 column in Data(d)
    y=1;
    
    pixelarea=(m_lldist([Lon1(x,y)-180 Lon2(x,y)-180],[Lat1(x,y) Lat2(x,y)]))*(m_lldist([Lon1(x,y)-180, Lon4(x,y)-180],[Lat1(x,y), Lat4(x,y)])); %JLL 20 Mar 2014: This calculates the area of the 50% pixel response area in km. (Removed /1000 b/c this function should return in km already)
    
    %JLL 18 Mar 2014: lCoordLat/Lon are defined in add2grid_5km_new, they
    %are the lat/lon values (here only the corners are used) as multiples
    %of the resolution away from the lat/lon minimum.
    x1=round(lCoordLat(x,y,1)); x1=clip(x1,minx,maxx);
    y1=round(lCoordLon(x,y,1)); y1=clip(y1,miny,maxy);
    x2=round(lCoordLat(x,y,2)); x2=clip(x2,minx,maxx);
    y2=round(lCoordLon(x,y,2)); y2=clip(y2,miny,maxy);
    x3=round(lCoordLat(x,y,3)); x3=clip(x3,minx,maxx);
    y3=round(lCoordLon(x,y,3)); y3=clip(y3,miny,maxy);
    x4=round(lCoordLat(x,y,4)); x4=clip(x4,minx,maxx);
    y4=round(lCoordLon(x,y,4)); y4=clip(y4,miny,maxy);
    
    
    if y2<y1; [x1,y1,x2,y2]=exchange_coord(x1,y1,x2,y2); end
    if y3<y1; [x1,y1,x3,y3]=exchange_coord(x1,y1,x3,y3); end
    if y4<y1; [x1,y1,x4,y4]=exchange_coord(x1,y1,x4,y4); end
    if y2>y3; [x2,y2,x3,y3]=exchange_coord(x2,y2,x3,y3); end
    if y4>y3; [x4,y4,x3,y3]=exchange_coord(x4,y4,x3,y3); end
    if x4>x2; [x4,y4,x2,y2]=exchange_coord(x4,y4,x2,y2); end
    %JLL 2-14-2014: x1 to x4 and y1 to y4 are now integers, between their
    %respective min and max values (derived from the lat/lon bound
    %specified in the main BEHR file) and arranged so that the points are in order
    %going around the outside (i.e., pt. 2 will not be caddycorner to pt. 1). Further,
    %the points usually end up counterclockwise, with 1 as the bottom
    %point.
    
    %JLL 2-14-2014: Load, in turn, each value of the fields loaded from the
    %OMI standard product
    
    BEHRColumnAmountNO2Trop_val = Data.BEHRColumnAmountNO2Trop(x);
    Time_val = Data.Time(x);
    ViewingZenithAngle_val = Data.ViewingZenithAngle(x);
    SolarZenithAngle_val = Data.SolarZenithAngle(x);
    ViewingAzimuthAngle_val = Data.ViewingAzimuthAngle(x);
    SolarAzimuthAngle_val = Data.SolarAzimuthAngle(x);
    CloudFraction_val = Data.CloudFraction(x);
    CloudRadianceFraction_val = Data.CloudRadianceFraction(x);
    ColumnAmountNO2_val = Data.ColumnAmountNO2(x);
    SlantColumnAmountNO2_val = Data.SlantColumnAmountNO2(x);
    TerrainHeight_val = Data.TerrainHeight(x);
    TerrainPressure_val = Data.TerrainPressure(x);
    TerrainReflectivity_val = Data.TerrainReflectivity(x);
    CloudPressure_val = Data.CloudPressure(x);
    RelativeAzimuthAngle_val = Data.RelativeAzimuthAngle(x);
    Latitude_val = Data.Latitude(x);
    Longitude_val = Data.Longitude(x);
    ColumnAmountNO2Trop_val = Data.ColumnAmountNO2Trop(x);
    GLOBETerpres_val = Data.GLOBETerpres(x);
    MODISAlbedo_val = Data.MODISAlbedo(x);
    BEHRAMFTrop_val = Data.BEHRAMFTrop(x);
    MODISCloud_val = Data.MODISCloud(x);
    Row_val = Data.Row(x);
    Swath_val = Data.Swath(x);
    AMFTrop_val = Data.AMFTrop(x);
    AMFStrat_val = Data.AMFStrat(x);
    TropopausePressure_val = Data.TropopausePressure(x);
    vcdQualityFlags_val = Data.vcdQualityFlags(x);
    XTrackQualityFlags_val = Data.XTrackQualityFlags(x);
    
    
    %dim=[maxx maxy];
    bottom=y1+1; %JLL 18 Mar 2014: Having the bottom advance by one ensures that data points right on the bottom/top border don't get double counted (at least, I think that's the point here)
    top=y3;
    if (bottom<maxy) && (top>=1); %JLL 2-14-2014: Why are these not separate conditions, i.e. "if bottom < maxy; bottom = clip(...); end; if top >= 1..."
        bottom=clip(bottom,1,maxy);
        top=clip(top,1,maxy);
    end
    
    for y_quad=bottom:1:top; %JLL 19 Mar 2014:
        if (x2>=calcline(y2,x1,y1,x3,y3)) && (x4<=calcline(y4,x1,y1,x3,y3)); %JLL 18 Mar 2014: Tests if the points are arranged counterclockwise
            if y_quad<y4; %JLL 19 Mar 2014: y1 and y3 will be the bottom and top point of the quadrangle, so y2 and y4 are vertices on the sides
                left=calcline(y_quad,x1,y1,x4,y4); %JLL 19 Mar 2014: Use the line between y1 and y4 to calc the left side for the given row...
            else
                left=calcline(y_quad,x4,y4,x3,y3); %JLL 19 Mar 2014: ...unless the row is above y4, then use the y4-y3 line
            end
            if y_quad<y2;
                right=calcline(y_quad,x1,y1,x2,y2); %JLL 19 Mar 2014: Same thought process for the right
            else
                right=calcline(y_quad,x2,y2,x3,y3);
            end
        else %JLL 19 Mar 2014: This section *should* handle any cases in which the corners are not arranged counterclockwise
            left=calcline(y_quad,x1,y1,x3,y3);
            if y2>y4;
                [x4,y4,x2,y2]=exchange_coord(x4,y4,x2,y2);
            end
            if y_quad<y2;
                right=calcline(y_quad,x1,y1,x2,y2);
            elseif y_quad<y4;
                right=calcline(y_quad,x2,y2,x4,y4);
            else
                right=calcline(y_quad,x4,y4,x3,y3);
            end
            if (x2<=calcline(y2,x1,y1,x3,y3)) && (x4<=calcline(y4,x1,y1,x3,y3));
                placeholder=left;
                left=right;
                right=placeholder;
                clear placeholder
            end
        end
        right=right-1; %JLL 19 Mar 2014: Like with the bottom, decrement this by 1 to avoid double counting points
        if left<=0;
        elseif (maxx>=right) && (right>=1) && (1<=left) && (left<maxx); %JLL 19 Mar 2014: Make sure the left and right bounds are inside the permissible limits
            clip(left,1,maxx); %JLL 19 Mar 2014: Kind of redundant...
            clip(right,1,maxx);
            for x_quad=left+1:right;
                % JLL 18 Jul 2014: If there is a valid trace gas column,
                % add it to the grid.  If there is already a measurement
                % there, average the new and existing measurements,
                % weighted by the number of measurments that went into the
                % existing average
                if BEHRColumnAmountNO2Trop(x_quad, y_quad) ~= 0 && ~isnan(Data.BEHRColumnAmountNO2Trop(x,y));
                    % Count, area, and areaweight require special handling
                    Count(x_quad,y_quad)=Count(x_quad,y_quad)+1;
                    Area(x_quad,y_quad)=nansum([Area(x_quad,y_quad)*(Count(x_quad,y_quad)-1), pixelarea])/(Count(x_quad, y_quad));
                    Areaweight(x_quad,y_quad)=Count(x_quad, y_quad)/Area(x_quad,y_quad);
                    
                    % Regular fields will be a running average
                    BEHRColumnAmountNO2Trop(x_quad, y_quad) = sum([BEHRColumnAmountNO2Trop(x_quad, y_quad)*(Count(x_quad, y_quad)-1), BEHRColumnAmountNO2Trop_val])/Count(x_quad,y_quad);
                    Time(x_quad, y_quad) = sum([Time(x_quad, y_quad)*(Count(x_quad, y_quad)-1), Time_val])/Count(x_quad,y_quad);
                    ViewingZenithAngle(x_quad, y_quad) = sum([ViewingZenithAngle(x_quad, y_quad)*(Count(x_quad, y_quad)-1), ViewingZenithAngle_val])/Count(x_quad,y_quad);
                    SolarZenithAngle(x_quad, y_quad) = sum([SolarZenithAngle(x_quad, y_quad)*(Count(x_quad, y_quad)-1), SolarZenithAngle_val])/Count(x_quad,y_quad);
                    ViewingAzimuthAngle(x_quad, y_quad) = sum([ViewingAzimuthAngle(x_quad, y_quad)*(Count(x_quad, y_quad)-1), ViewingAzimuthAngle_val])/Count(x_quad,y_quad);
                    SolarAzimuthAngle(x_quad, y_quad) = sum([SolarAzimuthAngle(x_quad, y_quad)*(Count(x_quad, y_quad)-1), SolarAzimuthAngle_val])/Count(x_quad,y_quad);
                    CloudFraction(x_quad, y_quad) = sum([CloudFraction(x_quad, y_quad)*(Count(x_quad, y_quad)-1), CloudFraction_val])/Count(x_quad,y_quad);
                    CloudRadianceFraction(x_quad, y_quad) = sum([CloudRadianceFraction(x_quad, y_quad)*(Count(x_quad, y_quad)-1), CloudRadianceFraction_val])/Count(x_quad,y_quad);
                    ColumnAmountNO2(x_quad, y_quad) = sum([ColumnAmountNO2(x_quad, y_quad)*(Count(x_quad, y_quad)-1), ColumnAmountNO2_val])/Count(x_quad,y_quad);
                    SlantColumnAmountNO2(x_quad, y_quad) = sum([SlantColumnAmountNO2(x_quad, y_quad)*(Count(x_quad, y_quad)-1), SlantColumnAmountNO2_val])/Count(x_quad,y_quad);
                    TerrainHeight(x_quad, y_quad) = sum([TerrainHeight(x_quad, y_quad)*(Count(x_quad, y_quad)-1), TerrainHeight_val])/Count(x_quad,y_quad);
                    TerrainPressure(x_quad, y_quad) = sum([TerrainPressure(x_quad, y_quad)*(Count(x_quad, y_quad)-1), TerrainPressure_val])/Count(x_quad,y_quad);
                    TerrainReflectivity(x_quad, y_quad) = sum([TerrainReflectivity(x_quad, y_quad)*(Count(x_quad, y_quad)-1), TerrainReflectivity_val])/Count(x_quad,y_quad);
                    CloudPressure(x_quad, y_quad) = sum([CloudPressure(x_quad, y_quad)*(Count(x_quad, y_quad)-1), CloudPressure_val])/Count(x_quad,y_quad);
                    RelativeAzimuthAngle(x_quad, y_quad) = sum([RelativeAzimuthAngle(x_quad, y_quad)*(Count(x_quad, y_quad)-1), RelativeAzimuthAngle_val])/Count(x_quad,y_quad);
                    Latitude(x_quad, y_quad) = sum([Latitude(x_quad, y_quad)*(Count(x_quad, y_quad)-1), Latitude_val])/Count(x_quad,y_quad);
                    Longitude(x_quad, y_quad) = sum([Longitude(x_quad, y_quad)*(Count(x_quad, y_quad)-1), Longitude_val])/Count(x_quad,y_quad);
                    ColumnAmountNO2Trop(x_quad, y_quad) = sum([ColumnAmountNO2Trop(x_quad, y_quad)*(Count(x_quad, y_quad)-1), ColumnAmountNO2Trop_val])/Count(x_quad,y_quad);
                    GLOBETerpres(x_quad, y_quad) = sum([GLOBETerpres(x_quad, y_quad)*(Count(x_quad, y_quad)-1), GLOBETerpres_val])/Count(x_quad,y_quad);
                    MODISAlbedo(x_quad, y_quad) = sum([MODISAlbedo(x_quad, y_quad)*(Count(x_quad, y_quad)-1), MODISAlbedo_val])/Count(x_quad,y_quad);
                    BEHRAMFTrop(x_quad, y_quad) = sum([BEHRAMFTrop(x_quad, y_quad)*(Count(x_quad, y_quad)-1), BEHRAMFTrop_val])/Count(x_quad,y_quad);
                    MODISCloud(x_quad, y_quad) = sum([MODISCloud(x_quad, y_quad)*(Count(x_quad, y_quad)-1), MODISCloud_val])/Count(x_quad,y_quad);
                    Row(x_quad, y_quad) = sum([Row(x_quad, y_quad)*(Count(x_quad, y_quad)-1), Row_val])/Count(x_quad,y_quad);
                    Swath(x_quad, y_quad) = sum([Swath(x_quad, y_quad)*(Count(x_quad, y_quad)-1), Swath_val])/Count(x_quad,y_quad);
                    AMFTrop(x_quad, y_quad) = sum([AMFTrop(x_quad, y_quad)*(Count(x_quad, y_quad)-1), AMFTrop_val])/Count(x_quad,y_quad);
                    AMFStrat(x_quad, y_quad) = sum([AMFStrat(x_quad, y_quad)*(Count(x_quad, y_quad)-1), AMFStrat_val])/Count(x_quad,y_quad);
                    TropopausePressure(x_quad, y_quad) = sum([TropopausePressure(x_quad, y_quad)*(Count(x_quad, y_quad)-1), TropopausePressure_val])/Count(x_quad,y_quad);
                    
                    % Flag fields will append the flag value to a matrix in
                    % a cell corresponding to this grid cell
                    
                    vcdQualityFlags(x_quad, y_quad) = {[vcdQualityFlags{x_quad, y_quad}, vcdQualityFlags_val]};
                    XTrackQualityFlags(x_quad, y_quad) = {[XTrackQualityFlags{x_quad, y_quad}, XTrackQualityFlags_val]};
                    
                    % If there is no existing field
                elseif ~isnan(Data.BEHRColumnAmountNO2Trop(x,y)) %JLL 19 Mar 2014: I added the logical test here, before this was just an 'else' statement, but it would make sense not to add a value if there was no valid NO2 column.
                    % Count, area, and areaweight require special handling
                    Count(x_quad,y_quad)=Count(x_quad,y_quad)+1;
                    Area(x_quad,y_quad)=pixelarea;
                    Areaweight(x_quad,y_quad)=1/pixelarea;
                    
                    % Regular fields will be a running average
                    BEHRColumnAmountNO2Trop(x_quad, y_quad) = BEHRColumnAmountNO2Trop_val;
                    Time(x_quad, y_quad) = Time_val;
                    ViewingZenithAngle(x_quad, y_quad) = ViewingZenithAngle_val;
                    SolarZenithAngle(x_quad, y_quad) = SolarZenithAngle_val;
                    ViewingAzimuthAngle(x_quad, y_quad) = ViewingAzimuthAngle_val;
                    SolarAzimuthAngle(x_quad, y_quad) = SolarAzimuthAngle_val;
                    CloudFraction(x_quad, y_quad) = CloudFraction_val;
                    CloudRadianceFraction(x_quad, y_quad) = CloudRadianceFraction_val;
                    ColumnAmountNO2(x_quad, y_quad) = ColumnAmountNO2_val;
                    SlantColumnAmountNO2(x_quad, y_quad) = SlantColumnAmountNO2_val;
                    TerrainHeight(x_quad, y_quad) = TerrainHeight_val;
                    TerrainPressure(x_quad, y_quad) = TerrainPressure_val;
                    TerrainReflectivity(x_quad, y_quad) = TerrainReflectivity_val;
                    CloudPressure(x_quad, y_quad) = CloudPressure_val;
                    RelativeAzimuthAngle(x_quad, y_quad) = RelativeAzimuthAngle_val;
                    Latitude(x_quad, y_quad) = Latitude_val;
                    Longitude(x_quad, y_quad) = Longitude_val;
                    ColumnAmountNO2Trop(x_quad, y_quad) = ColumnAmountNO2Trop_val;
                    GLOBETerpres(x_quad, y_quad) = GLOBETerpres_val;
                    MODISAlbedo(x_quad, y_quad) = MODISAlbedo_val;
                    BEHRAMFTrop(x_quad, y_quad) = BEHRAMFTrop_val;
                    MODISCloud(x_quad, y_quad) = MODISCloud_val;
                    Row(x_quad, y_quad) = Row_val;
                    Swath(x_quad, y_quad) = Swath_val;
                    AMFTrop(x_quad, y_quad) = AMFTrop_val;
                    AMFStrat(x_quad, y_quad) = AMFStrat_val;
                    TropopausePressure(x_quad, y_quad) = TropopausePressure_val;
                    
                    % Flag fields will append the flag value to a matrix in
                    % a cell corresponding to this grid cell
                    vcdQualityFlags(x_quad, y_quad) = {vcdQualityFlags_val};
                    XTrackQualityFlags(x_quad, y_quad) = {XTrackQualityFlags_val};
                end
            end
        end
    end
end

% Create the OMI structure for output
OMI.BEHRColumnAmountNO2Trop = BEHRColumnAmountNO2Trop;
OMI.Time = Time;
OMI.ViewingZenithAngle = ViewingZenithAngle;
OMI.SolarZenithAngle = SolarZenithAngle;
OMI.ViewingAzimuthAngle = ViewingAzimuthAngle;
OMI.SolarAzimuthAngle = SolarAzimuthAngle;
OMI.CloudFraction = CloudFraction;
OMI.CloudRadianceFraction = CloudRadianceFraction;
OMI.ColumnAmountNO2 = ColumnAmountNO2;
OMI.SlantColumnAmountNO2 = SlantColumnAmountNO2;
OMI.TerrainHeight = TerrainHeight;
OMI.TerrainPressure = TerrainPressure;
OMI.TerrainReflectivity = TerrainReflectivity;
OMI.CloudPressure = CloudPressure;
OMI.RelativeAzimuthAngle = RelativeAzimuthAngle;
OMI.Latitude = Latitude;
OMI.Longitude = Longitude;
OMI.ColumnAmountNO2Trop = ColumnAmountNO2Trop;
OMI.GLOBETerpres = GLOBETerpres;
OMI.MODISAlbedo = MODISAlbedo;
OMI.BEHRAMFTrop = BEHRAMFTrop;
OMI.MODISCloud = MODISCloud;
OMI.Row = Row;
OMI.Swath = Swath;
OMI.AMFTrop = AMFTrop;
OMI.AMFStrat = AMFStrat;
OMI.Count = Count;
OMI.Area = Area;
OMI.Areaweight = Areaweight;
OMI.TropopausePressure = TropopausePressure;
OMI.vcdQualityFlags = vcdQualityFlags;
OMI.XTrackQualityFlags = XTrackQualityFlags;

end
