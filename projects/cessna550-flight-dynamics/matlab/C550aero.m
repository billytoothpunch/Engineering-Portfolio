function [F,M] = C550aero(alpha,beta,Mach,De,Da,Dr,p,q,r,adot)
% C550aero  Aerodynamic coefficient model for the Cessna 550
%
% Inputs:
%   alpha,beta : rad
%   Mach       : Mach number
%   De,Da,Dr   : control deflections, deg
%   p,q,r      : non-dimensional angular rates
%   adot       : non-dimensional alpha rate
%
% Outputs:
%   F = [CD; CY; CL]
%   M = [Cl; Cm; Cn]

global C550
if isempty(C550), C550init; end
AC = C550;

De = deg2rad(De);
Da = deg2rad(Da);
Dr = deg2rad(Dr);

mc = sqrt(max(1 - Mach.^2, 0.05));

if rad2deg(alpha) > 6
    aplus = deg2rad(rad2deg(alpha) - 6);
else
    aplus = 0;
end

ke = interp1(deg2rad([-10 10 20 25 90]), [1.0 1.0 0.7 0.4 0.4], alpha, 'linear', 'extrap');
ka = interp1(deg2rad([-10 10 20 25 90]), [1.0 1.0 0.4 0.3 0.3], alpha, 'linear', 'extrap');
kr = interp1(deg2rad([-10 10 20 25 90]), [1.0 1.0 0.9 0.6 0.2], alpha, 'linear', 'extrap');

CL = AC.CL0 + AC.CLa/mc*alpha + AC.CLa2*aplus^2 + AC.CLadot*adot + AC.CLq*q + AC.CLde*ke*De;
CD = (AC.CD0 + (AC.CL0 + AC.CLa*alpha - AC.CLDmin)^2/(pi*AC.AR*AC.e_osw) + AC.CDb*abs(beta) + AC.CDde*ke*De) / mc;
Cm = AC.Cm0 + AC.Cma*alpha + AC.Cma2*aplus^2 + AC.Cmadot*adot + AC.Cmq*q + AC.Cmde*ke*De;

Cl = AC.Clb*beta + AC.Clp*p + AC.Clr*r + AC.Clda*ka*Da + AC.Cldr*kr*Dr;
Cn = AC.Cnb*beta + (AC.Cnp_alpha*alpha)*p + AC.Cnr*r + AC.Cnda*ka*Da + AC.Cndr*kr*Dr;
CY = AC.CYb*beta + AC.CYp*p + AC.CYr*r + AC.CYda*ka*Da + AC.CYdr*kr*Dr;

F = [CD; CY; CL];
M = [Cl; Cm; Cn];
end
