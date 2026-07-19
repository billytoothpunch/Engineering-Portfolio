function AC = C550init()
% C550init  Initialise Cessna 550 model data for the flight-dynamics model
% Author: Muhammed Billal Noor

global C550
global name surname

name    = 'Billal';
surname = 'Noor';

AC.Name = 'Billal Noor';
AC.Type = 'Cessna 550 Citation';

% Geometry and inertial data from the coursework aircraft data sheet
AC.b   = 15.90;      % m
AC.c   = 2.09;       % m
AC.S   = 30.00;      % m^2
AC.m   = 4157.00;    % kg
AC.g   = 9.80665;    % m/s^2
AC.Ixx = 12392.00;   % kg m^2
AC.Iyy = 31501.00;   % kg m^2
AC.Izz = 41908.00;   % kg m^2
AC.Ixz = 2252.20;    % kg m^2
AC.Dx  = 0.00;       % percent MAC
AC.RE  = [-2.4 -1.2 -0.64; -2.4 1.2 -0.64];   % m
AC.eps_engine_deg = 0.0;                      % deg

% Aerodynamic derivatives
AC.CL0    = 0.1758;
AC.CLa    = 4.6605;
AC.CLa2   = -10.7753;
AC.CLde   = 0.4957;
AC.CLadot = 2.26;
AC.CLq    = 4.49;

AC.CD0    = 0.019;
AC.CDb    = 0.16;
AC.CDde   = -0.01857;
AC.CLDmin = 0.212;
AC.e_osw  = 0.78;
AC.AR     = 15.09/2.09;

AC.Cm0    = 0.0183;
AC.Cma    = -0.5683;
AC.Cma2   = 1.05;
AC.Cmq    = -13.17;
AC.Cmadot = -7.426;
AC.Cmde   = -0.5547;

AC.Clb    = -0.0454;
AC.Clp    = -0.1340;
AC.Clr    = 0.1412;
AC.Clda   = -0.0853;
AC.Cldr   = -0.0389;

AC.Cnb    = 0.0804;
AC.Cnp_alpha = 0.000268;   % Cnp(alpha) = 0.000268*alpha(rad)
AC.Cnr    = -0.0496;
AC.Cnda   = 0.0;
AC.Cndr   = 0.0492;

AC.CYb    = -0.5222;
AC.CYda   = -0.2932;
AC.CYdr   = 0.1574;
AC.CYp    = -0.5000;
AC.CYr    = 0.8971;

% Twin JT15D-4 installation: practical smooth thrust model for simulation
AC.Tmax_sl_total = 2*11300;   % N total static sea-level thrust estimate

C550 = AC;
assignin('base','C550',AC);
fprintf('C550init loaded for %s\n', AC.Name);
end
