function xdot = EoM12(~,x,u)
% EoM12  Nonlinear 12-state rigid-body equations of motion for Cessna 550
% State x = [u v w p q r phi theta psi xe ye ze]'
% Control u = [De Da Dr Dt]'

global C550 V_dot alpha_dot beta_dot
if isempty(C550), C550init; end
AC = C550;

U = u(:);
De = U(1); Da = U(2); Dr = U(3); Dt = U(4);

ub = x(1); vb = x(2); wb = x(3);
p = x(4); q = x(5); r = x(6);
phi = x(7); theta = x(8); psi = x(9);
altitude = -x(12);

V = max(1.0, sqrt(ub^2 + vb^2 + wb^2));
alpha = atan2(wb,ub);
beta = asin(max(-1,min(1,vb/V)));

[rho,a] = atmosphere(altitude);
Mach = V/max(a,1e-6);
qbar = 0.5*rho*V^2;

ph = p*AC.b/(2*V);
qh = q*AC.c/(2*V);
rh = r*AC.b/(2*V);
ah = alpha_dot*AC.c/(2*V);

[Fcoef,Mcoef] = C550aero(alpha,beta,Mach,De,Da,Dr,ph,qh,rh,ah);
CD = Fcoef(1); CY = Fcoef(2); CL = Fcoef(3);
Cl = Mcoef(1); Cm = Mcoef(2); Cn = Mcoef(3);

Cw = [-CD; CY; -CL];
ca = cos(alpha); sa = sin(alpha); cb = cos(beta); sb = sin(beta);
Tbw = [ca*cb, -ca*sb, -sa; sb, cb, 0; sa*cb, -sa*sb, ca];
Faero_b = qbar*AC.S*(Tbw*Cw);
Maero_b = qbar*AC.S*[AC.b*Cl; AC.c*Cm; AC.b*Cn];

[T_each,~] = TurboFanEngine(altitude,Mach,Dt);
engine_dir = [cosd(AC.eps_engine_deg); 0; -sind(AC.eps_engine_deg)];
Fth_b = zeros(3,1); Mth_b = zeros(3,1);
for k = 1:2
    Fk = T_each(k)*engine_dir;
    rk = AC.RE(k,:)';
    Fth_b = Fth_b + Fk;
    Mth_b = Mth_b + cross(rk,Fk);
end

Fg_b = AC.m*AC.g*[-sin(theta); cos(theta)*sin(phi); cos(theta)*cos(phi)];
Ftot = Faero_b + Fth_b + Fg_b;
Mtot = Maero_b + Mth_b;

omega = [p; q; r];
vel = [ub; vb; wb];
uvwdot = Ftot/AC.m - cross(omega,vel);

I = [AC.Ixx 0 -AC.Ixz; 0 AC.Iyy 0; -AC.Ixz 0 AC.Izz];
omegadot = I \ (Mtot - cross(omega,I*omega));

sphi = sin(phi); cphi = cos(phi);
cth = cos(theta);
sec_th = 1/max(abs(cth),1e-4);
E = [1 sphi*tan(theta) cphi*tan(theta); 0 cphi -sphi; 0 sphi*sec_th cphi*sec_th];
angdot = E*omega;

cp = cos(psi); sp = sin(psi); sth = sin(theta);
Rbe = [cth*cp, sphi*sth*cp-cphi*sp, cphi*sth*cp+sphi*sp; ...
       cth*sp, sphi*sth*sp+cphi*cp, cphi*sth*sp-sphi*cp; ...
       -sth,   sphi*cth,            cphi*cth];
posdot = Rbe*vel;

xdot = [uvwdot; omegadot; angdot; posdot];

V_dot = (vel'*uvwdot)/max(V,1e-6);
alpha_dot = (vel(1)*uvwdot(3) - vel(3)*uvwdot(1)) / max(vel(1)^2 + vel(3)^2,1e-6);
beta_dot = (uvwdot(2)*V - vel(2)*V_dot) / max(V^2*cos(beta),1e-6);
end
