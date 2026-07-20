%% Piper Cub airframe mass-estimation script
% Author: Billal Noor
% Purpose: Estimate structural masses and centres of gravity from an
% XFLR5-exported airfoil coordinate file.
%
% Keep the XFLR5 data filename unchanged. The script resolves paths from
% its own location so it can be run from any MATLAB working directory.

clear; clc; close all;

%% Material properties
sheet_thickness = 0.003;  % m
rho_balsa   = 250;        % kg/m^3
rho_plywood = 680;        % kg/m^3 (retained for alternative studies)
rho_pine    = 500;        % kg/m^3

%% Load the XFLR5 airfoil coordinate file
script_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(script_dir);
airfoil_file = fullfile(project_dir, 'xflr5', 'R3_GRP_PROJECT(1).dat');

if ~isfile(airfoil_file)
    error('Airfoil file not found: %s', airfoil_file);
end

opts = detectImportOptions(airfoil_file, 'FileType', 'text');
opts.DataLines = [2 Inf];  % first line is the XFLR5 airfoil name
D = readmatrix(airfoil_file, opts);
D = D(:, 1:2);
D = D(all(isfinite(D), 2), :);

if size(D,1) < 4
    error('The XFLR5 coordinate file does not contain enough valid points.');
end

x = D(:,1);
y = D(:,2);

% Split at the leading edge. XFLR5 coordinates normally run from the
% trailing edge around the upper surface to the leading edge, then back
% along the lower surface.
[~, i_le] = min(x);
x_upper = x(1:i_le);  y_upper = y(1:i_le);
x_lower = x(i_le:end); y_lower = y(i_le:end);

% interp1 requires increasing, unique x values.
[x_upper, iu] = unique(flipud(x_upper), 'stable');
y_upper = flipud(y_upper); y_upper = y_upper(iu);
[x_lower, il] = unique(x_lower, 'stable');
y_lower = y_lower(il);

figure('Name','Airfoil geometry');
plot(x_upper, y_upper, 'LineWidth', 1.5); hold on;
plot(x_lower, y_lower, 'LineWidth', 1.5);
axis equal; grid on;
xlabel('x/c'); ylabel('y/c');
legend('Upper surface','Lower surface','Location','best');
title('XFLR5 airfoil coordinates');

%% Normalised airfoil area and centroid
x_min = max(min(x_upper), min(x_lower));
x_max = min(max(x_upper), max(x_lower));
x_grid = linspace(x_min, x_max, 4001);
yu = interp1(x_upper, y_upper, x_grid, 'pchip');
yl = interp1(x_lower, y_lower, x_grid, 'pchip');
thickness = max(yu - yl, 0);

A0 = trapz(x_grid, thickness);           % normalised cross-sectional area
x0_cg = trapz(x_grid, x_grid.*thickness) / A0;
c0 = x_max - x_min;                     % normally 1 for normalised data
ma0 = rho_balsa * sheet_thickness * A0; % mass for c = c0

fprintf('Normalised area: %.6f m^2 (for c = %.3f m)\n', A0, c0);
fprintf('Normalised rib mass: %.4f kg\n', ma0);
fprintf('Airfoil centroid: %.4f c from the leading edge\n', x0_cg/c0);

%% Example rib at a selected chord
chord = 0.2; % m
area_scaled = A0 * (chord/c0)^2;
volume_scaled = sheet_thickness * area_scaled;
mass_scaled = rho_balsa * volume_scaled;
fprintf('Mass of a %.3f m chord rib: %.4f kg\n', chord, mass_scaled);

%% Generic rectangular spar example
span = 1.2; % m
spar_width = 0.003; % m
spar_thickness = 0.005; % m
spar_mass_example = rho_pine * spar_width * spar_thickness * span;
fprintf('Example spar mass: %.4f kg\n', spar_mass_example);

%% Main wing estimate
wing_chords = [0.283, 0.283, 0.283, 0.282, 0.277, 0.267, 0.254, ...
               0.237, 0.215, 0.148, 0.138, 0.084, 0.017];
wing_le_offsets = [0.000, 0.000, 0.000, 0.001, 0.002, 0.004, 0.006, ...
                   0.009, 0.016, 0.028, 0.047, 0.066, 0.090];
wing_span_stations = [0.000, 0.035, 0.084, 0.142, 0.199, 0.253, 0.311, ...
                      0.368, 0.424, 0.482, 0.541, 0.590, 0.624];

wing_rib_mass = ma0 .* (wing_chords/c0).^2;
wing_rib_xcg = wing_le_offsets + wing_chords*(x0_cg/c0);
wing_half_ribs_mass = sum(wing_rib_mass);
wing_ribs_span_cg = sum(wing_rib_mass .* wing_span_stations) / wing_half_ribs_mass;

spar_width = 0.004; spar_thickness = 0.005;
wing_span = 2*0.624;
wing_spar_mass = 6 * rho_pine * spar_width * spar_thickness * wing_span;
wing_structure_mass = 2*wing_half_ribs_mass + wing_spar_mass;

wing_table = table(wing_chords', wing_le_offsets', wing_span_stations', ...
                   wing_rib_xcg', wing_rib_mass', ...
    'VariableNames', {'Chord_m','LE_Offset_m','SpanStation_m','RibXcg_m','RibMass_kg'});
disp(wing_table);
fprintf('Estimated wing structure mass: %.4f kg\n', wing_structure_mass);
fprintf('Half-wing rib-system spanwise CG: %.4f m\n', wing_ribs_span_cg);

%% Horizontal stabiliser estimate
stab_chords = 0.001*[86 86 139 138 134 128 117 102 61 10];
stab_le_offsets = 0.001*[0 0 1 2 6 10 18 28 54 81];
stab_span_stations = 0.001*[0 13 32 54 72 93 114 134 164 177];

stab_rib_mass = ma0 .* (stab_chords/c0).^2;
stab_rib_xcg = stab_le_offsets + stab_chords*(x0_cg/c0);
stab_half_ribs_mass = sum(stab_rib_mass);
stab_ribs_span_cg = sum(stab_rib_mass .* stab_span_stations) / stab_half_ribs_mass;

stab_span = 2*0.177;
stab_spar_mass = 6 * rho_pine * spar_width * spar_thickness * stab_span;
stab_structure_mass = 2*stab_half_ribs_mass + stab_spar_mass;
fin_structure_mass = 0.5*stab_structure_mass; % preliminary approximation

fprintf('Estimated stabiliser structure mass: %.4f kg\n', stab_structure_mass);
fprintf('Estimated fin structure mass: %.4f kg\n', fin_structure_mass);
fprintf('Half-stabiliser rib-system spanwise CG: %.4f m\n', stab_ribs_span_cg);

%% Fuselage-frame estimate
frame_x = 0.001*[-156 -85 0 98 200 214 232 252 287 315 447 510 568 650 719];
frame_a = 0.01*[8 5 6 10 10 10 10 10 10 10 10 8 6 4 2];
frame_b = 0.01*[9 13 14 15 16 17 18 18 18 17 15 14 12 10 6];
frame_area = (pi/4) .* frame_a .* frame_b;
frame_mass = rho_balsa * sheet_thickness .* frame_area;
fuselage_length = max(frame_x) - min(frame_x);
fuselage_longeron_mass = 4 * rho_pine * spar_width * spar_thickness * fuselage_length;
fuselage_frame_mass = sum(frame_mass) + fuselage_longeron_mass;
fuselage_xcg = sum(frame_mass .* frame_x) / sum(frame_mass);

fprintf('Estimated fuselage frame/longeron mass: %.4f kg\n', fuselage_frame_mass);
fprintf('Estimated fuselage-frame longitudinal CG: %.4f m\n', fuselage_xcg);
