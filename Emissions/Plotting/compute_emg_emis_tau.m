function [ E, uncert_E, tau, uncert_tau ] = compute_emg_emis_tau( a, uncert_a, x0, uncert_x0, wind_mode, varargin )
%[ E, UNCERT_E, TAU, UNCERT_TAU ] = COMPUTE_EMG_EMIS_TAU( A, UNCERT_A, X0, UNCERT_X0, 'vec', WIND_SPEED_VEC )
%   This function computes the values of emissions, lifetime, and their
%   uncertainties from the values of a, x_0, their uncertainties, and the
%   vector of wind speeds for days used in generating the line densities
%   that fit. For example, if windvel is a 90x1 vector of wind speeds (in
%   m/s) for the 90 days considered for the line densities and only days
%   with wind 3 m/s were used, then pass windvel(windvel>3) as
%   WIND_SPEED_VEC. This is used to compute the average wind speed and
%   error in the wind (as a 95% confidence interval) for use in the
%   uncertainty calculations. A and X0 must be row vectors of the same
%   size, and UNCERT_A and UNCERT_X0 must be 2-by-n matrices, where n is
%   the number of elements of A and X0. The first row must be the
%   uncertainty of the parameters below their value, the second row the
%   uncertainty above. Sigh. I hate asymmetric uncertainties.
%
%   Even though the changes in a and x0 are correlated, we will still add
%   them in quadrature because they are not perfectly correlated.  Ideally,
%   we would have information on how the uncertainty envelope of e.g. x0
%   changes for different values of a, but that would be much more
%   complicated. Technically, that is what we should have because the
%   assumption that the uncertainty is small enough to not significantly
%   change the slopes is wrong, but we'll go with it for now.
%
%[ E, UNCERT_E, TAU, UNCERT_TAU ] = COMPUTE_EMG_EMIS_TAU( A, UNCERT_A, X0, UNCERT_X0, 'avg', WIND_SPEED_MEAN, WIND_SPEED_ERROR)
%   In this format, the mean and error of the wind speed is given instead.
%   This can be useful if you just stored these values rather than the full
%   vector, or if you wish to use an alternate definition of error in the
%   wind speed 

%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% INPUT CHECKING %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~isrow(a) || ~isrow(x0) || length(a) ~= length(x0)
    E.badinput('A and X0 must be row vectors of the same length')
end

if size(uncert_a,2) ~= length(a) || size(uncert_x0,2) ~= length(x0) || size(uncert_a,1) ~= 2 || size(uncert_x0,1) ~= 2
    E.badinput('UNCERT_A and UNCERT_X0 must be 2-by-length(a) matrices')
end

allowed_wind_modes = {'vec','avg'};
if ~ismember(wind_mode, allowed_wind_modes)
    E.badinput('WIND_MODE (5th input) must be one of %s', strjoin(allowed_wind_modes, ', '));
end

switch lower(wind_mode)
    case 'vec'
        if numel(varargin) < 1
            E.badinput('When using WIND_MODE == ''vec'' there must be one additional input, the vector of wind speeds');
        end
    case 'avg'
        if numel(varargin) < 2
            E.badinput('When using WIND_MODE == ''vec'' there must be two additional inputs, the mean and error of wind speeds');
        elseif any(~iscellcontents(varargin, 'isscalar'))
            E.badinput('When using WIND_MODE == ''vec'' both additional inputs are expected to be scalars.')
        end
end

%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% MAIN FUNCTION %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%

if strcmpi(wind_mode, 'vec')
    wind_speed_vec = varargin{1};
    avg_wind = mean(wind_speed_vec/1000*3600); % windvel in m/s, convert to km/h
    student_t = tinv(0.975, numel(wind_speed_vec)); %tinv gives one-tailed, we want two-tailed 95% CI
    err_wind = (student_t * std(wind_speed_vec/1000*3600))/sqrt(numel(wind_speed_vec));
else
    avg_wind = varargin{1};
    err_wind = varargin{2};
end
E = 1.32 .* a .* avg_wind ./ x0;

% Calculate assumed mass of NOx if NOx:NO2 ratio is 1.32
% MM NO = 30.01 g/mol
% MM NO2 = 46.01 g/mol
mol2Mg = (1/1.32 * 46.01 + (1-1/1.32)*30.01)*1e-6;
E = E * mol2Mg;

tau = x0 ./ avg_wind;
% Uncertainty in emissions needs to add the uncertainty in the
% NOx:NO2 ratio (10%). Uncertainty in lifetime will just depend
% on uncertainty in x_0

% We need the a and x0 matrices to be the same size as their uncertainty
% now.
a = repmat(a,2,1);
x0 = repmat(x0,2,1);
tau_tmp = repmat(tau,2,1);
%Simple case (assumes average wind has no error)
%uncert_tau = uncert_x0  ./ avg_wind;
%Full case (consider uncertainty as 95% CI
uncert_tau = sqrt( (uncert_x0 ./ avg_wind).^2 + ( err_wind .* -x0 ./ avg_wind.^2 ).^2 );

% We'll handle the uncertainty in E in two steps. First,
% compute the percent error due to error in a and tau. Then add
% this in quadrature with the 10% error due to the NOx:NO2
% ratio.
% init_uncert_E_squared = (uncert_a .* mol2Mg ./ tau).^2 + (uncert_tau .* -a .* mol2Mg ./ (tau .^ 2)).^2;
% per_uncert_E = sqrt( init_uncert_E_squared ./ (E .^ 2) + 0.1 .^ 2 );
% uncert_E = E .* per_uncert_E;
NOxNO2 = 1.32;
uncert_NOxNO2 = 0.1 * NOxNO2;
uncert_E = sqrt((a .* mol2Mg ./ tau_tmp .* uncert_NOxNO2).^2 + (NOxNO2 ./ tau_tmp .* uncert_a .* mol2Mg).^2 + (-NOxNO2 .* a .* mol2Mg ./ tau_tmp.^2 .* uncert_tau).^2);

end

