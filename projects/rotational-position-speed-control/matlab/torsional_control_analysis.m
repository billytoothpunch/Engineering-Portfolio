%% Rotational Position and Speed Control Analysis
% This script:
%  (1) Loads your exported ECP "Export Raw Data" text files from LAB 2.zip
%  (2) Identifies J, c, and dry friction Tf using engineering model parameter identification (robust)
%  (3) Creates required overlay plots (Position Control, PD Control, Speed Control) using MATLAB plot()
%  (4) Prints transient metric tables for Transient Metrics and PD Metrics (OS%, tp, tr, ts, ess)
%  (5) Produces pole movement plots for Pole Analysis using your identified J,c
%
% clear; close all; clc;

%% ------------------------ SETTINGS ------------------------
zipFile = 'LAB 2.zip';
dataDir = fullfile(pwd,'LAB2_unzipped');

COUNTS_PER_REV = 16000;
DEG_PER_COUNT  = 360/COUNTS_PER_REV;
RAD_PER_COUNT  = 2*pi/COUNTS_PER_REV;

ENC_COL = 4;     % Encoder 1 position column in exported matrix (counts)

Va = 0.25;       % open-loop test voltage
Ta = 0.6*Va;     % motor torque Ta=0.6*Va [N*m] (lab sheet)

RISE_LIMS  = [0.1 0.9];  % 10–90% rise time
SETTLE_TOL = 0.02;       % 2% band

%% ------------------------ UNZIP ------------------------
if ~exist(dataDir,'dir'), mkdir(dataDir); end
if isempty(dir(fullfile(dataDir,'*data.txt'))) && isempty(dir(fullfile(dataDir,'*.txt')))
    unzip(zipFile, dataDir);
end

%% ------------------------ Parameter Identification: PARAMETER ID (parameter identification) ------------------------
% Find your open-loop file (your zip contains something like open_loop)25_4000_1.txt)
ol = dir(fullfile(dataDir,'open_loop*.txt'));
if isempty(ol), ol = dir(fullfile(dataDir,'Open_loop*.txt')); end
if isempty(ol)
    error('Open-loop .txt file not found in %s', dataDir);
end

D = loadECP(fullfile(ol(1).folder, ol(1).name));

% Time + ensure strictly increasing / unique (prevents gradient issues)
t_raw = D(:,2);
[t, uniqIdx] = unique(t_raw, 'stable');
D = D(uniqIdx,:);

theta = D(:,ENC_COL) * RAD_PER_COUNT;                  % rad
omega = gradient(theta)./gradient(t);                  % rad/s
omega = smoothdata(omega,'movmedian',7);               % mild smoothing

% --- Robust p1, p2, p3 selection ---
[~,iPk] = max(omega);
omPk = omega(iPk);

thr = 0.10*omPk;  % 10% threshold (more robust than 5% for noisy logs)

i1 = find(omega >= thr, 1, 'first');   % p1
if isempty(i1)
    error('Could not find p1 (omega never exceeds threshold). Check open-loop data.');
end

i3 = find(((1:numel(omega))' > iPk) & (omega <= thr), 1, 'first'); % p3
if isempty(i3)
    i3 = numel(omega); % fallback: end of record
end

target = 0.70*omPk; % mid-deceleration target
i2 = find(((1:numel(omega))' > iPk) & (omega <= target), 1, 'first'); % p2
if isempty(i2)
    i2 = round((iPk + i3)/2); % fallback: midpoint
end

% --- Tangent slopes (angular accelerations) ---
win = 0.25; % seconds
a1 = localSlope(t, omega, i1, win);
a2 = localSlope(t, omega, i2, win);
a3 = localSlope(t, omega, i3, win);
w2 = omega(i2); w2 = w2(1); % force scalar

% If not enough points / omega2 too small, widen window automatically
if any(isnan([a1 a2 a3])) || abs(w2) < 1e-6
    win = 0.50;
    a1 = localSlope(t, omega, i1, win);
    a2 = localSlope(t, omega, i2, win);
    a3 = localSlope(t, omega, i3, win);
    w2 = omega(i2); w2 = w2(1);
end

if any(isnan([a1 a2 a3])) || abs(w2) < 1e-6
    error('Open-loop identification failed (insufficient points or omega2 ~ 0). Try increasing win or check data.');
end

% --- Parameter identification (engineering model 3.2) ---
J  = Ta/(a1 - a3);
c  = -J*(a2 - a3)/w2;
Tf = -J*a3;

fprintf('\n=== Parameter Identification Parameter Identification (engineering model 3.2) ===\n');
fprintf('Va = %.2f V, Ta = %.3f N*m\n', Va, Ta);
fprintf('alpha1 = %.3f rad/s^2, alpha2 = %.3f rad/s^2, alpha3 = %.3f rad/s^2, omega2 = %.3f rad/s\n', a1,a2,a3,w2);
fprintf('J  = %.6f kg*m^2\n', J);
fprintf('c  = %.6f N*m*s/rad\n', c);
fprintf('Tf = %.4f N*m\n', Tf);

% Figure 1 (open-loop θ and ω)
figure('Name','Figure 1 - Open loop theta and omega');
yyaxis left;
plot(t, D(:,ENC_COL)*DEG_PER_COUNT); grid on;
ylabel('\theta (deg)');
yyaxis right;
plot(t, omega * (180/pi)); % rad/s -> deg/s
ylabel('\omega (deg/s)');
xlabel('Time (s)');
title('Open-loop response (Va=0.25V): \theta(t) and \omega(t)');

%% ------------------------ Position Control + Transient Metrics: P POSITION CONTROL ------------------------
pFiles = dir(fullfile(dataDir,'closedloop-240-4000-1_*data.txt'));

P = struct([]);
for i = 1:numel(pFiles)
    fn = pFiles(i).name;

    % P files: "..._0.005data.txt" or "..._0.03data.txt" or "..._0.01_0_0data.txt"
    if contains(fn,'_0.01_0.') || contains(fn,'_0.01_0_0') || (~contains(fn,'_0.01_') && ~contains(fn,'_0.0'))
        tok = regexp(fn,'closedloop-240-4000-1_([0-9.]+)','tokens','once');
        if isempty(tok), continue; end
        Kp = str2double(tok{1});

        D = loadECP(fullfile(pFiles(i).folder, fn));
        tt_raw = D(:,2);
        [tt, uniqIdx] = unique(tt_raw,'stable');
        D = D(uniqIdx,:);

        r_deg = D(:,3)*DEG_PER_COUNT;
        y_deg = D(:,ENC_COL)*DEG_PER_COUNT;

        sl = firstStepSlice(tt, r_deg);
        tseg = tt(sl) - tt(sl(1));

        M = stepMetrics(tseg, y_deg(sl), r_deg(sl), RISE_LIMS, SETTLE_TOL);

        P(end+1).Kp = Kp; %#ok<SAGROW>
        P(end).t = tseg;
        P(end).r = r_deg(sl);
        P(end).y = y_deg(sl);
        P(end).M = M;
    end
end

if isempty(P), error('No P-control files found (closedloop-240-4000-1_*data.txt).'); end

[~,idx] = sort([P.Kp]); P = P(idx);

% Figure 2 (Position Control)
figure('Name','Figure 2 - Position Control P control overlay (varying Kp)');
hold on; grid on;
for i = 1:numel(P)
    plot(P(i).t, P(i).y, 'DisplayName', sprintf('Kp=%.3g', P(i).Kp));
end
plot(P(1).t, P(1).r, 'k--', 'DisplayName', 'Reference');
xlabel('Time (s)'); ylabel('Position (deg)');
title('Position Control: Position step response (P control) for different Kp');
legend('Location','best');

% Table for Transient Metrics
fprintf('\n=== Transient Metrics Transient Metrics (P control) ===\n');
fprintf('%6s %8s %8s %8s %10s %10s\n','Kp','OS%','tp(s)','tr(s)','ts(s)','ess(deg)');
for i = 1:numel(P)
    M = P(i).M;
    fprintf('%6.3g %8.2f %8.3f %8.3f %10s %10.3f\n', ...
        P(i).Kp, M.OS, M.tp, M.tr, ...
        tern(isnan(M.ts),'—',sprintf('%.3f',M.ts)), M.ess);
end

%% ------------------------ PD Control + PD Metrics: PD POSITION CONTROL (vary Kd, Kp=0.01) ------------------------
PD = struct([]);
for i = 1:numel(pFiles)
    fn = pFiles(i).name;

    if contains(fn,'closedloop-240-4000-1_0.01_') && ~contains(fn,'_0_0data')
        tok = regexp(fn,'closedloop-240-4000-1_0\.01_([0-9.]+)_','tokens','once');
        if isempty(tok), continue; end
        Kd = str2double(tok{1});

        D = loadECP(fullfile(pFiles(i).folder, fn));
        tt_raw = D(:,2);
        [tt, uniqIdx] = unique(tt_raw,'stable');
        D = D(uniqIdx,:);

        r_deg = D(:,3)*DEG_PER_COUNT;
        y_deg = D(:,ENC_COL)*DEG_PER_COUNT;

        sl = firstStepSlice(tt, r_deg);
        tseg = tt(sl) - tt(sl(1));

        M = stepMetrics(tseg, y_deg(sl), r_deg(sl), RISE_LIMS, SETTLE_TOL);

        PD(end+1).Kp = 0.01; %#ok<SAGROW>
        PD(end).Kd = Kd;
        PD(end).t = tseg;
        PD(end).r = r_deg(sl);
        PD(end).y = y_deg(sl);
        PD(end).M = M;
    end
end

if isempty(PD), error('No PD-control files found for Kp=0.01 (closedloop-240-4000-1_0.01_*_*data.txt).'); end

[~,idx] = sort([PD.Kd]); PD = PD(idx);

% Figure 3 (PD Control)
figure('Name','Figure 3 - PD Control PD control overlay (varying Kd)');
hold on; grid on;
for i = 1:numel(PD)
    plot(PD(i).t, PD(i).y, 'DisplayName', sprintf('Kd=%.3g', PD(i).Kd));
end
plot(PD(1).t, PD(1).r, 'k--', 'DisplayName', 'Reference');
xlabel('Time (s)'); ylabel('Position (deg)');
title('PD Control: Position step response (PD / velocity feedback), Kp=0.01');
legend('Location','best');

% Table for PD Metrics
fprintf('\n=== PD Metrics Transient Metrics (PD control, Kp=0.01) ===\n');
fprintf('%6s %6s %8s %8s %8s %10s %10s\n','Kp','Kd','OS%','tp(s)','tr(s)','ts(s)','ess(deg)');
for i = 1:numel(PD)
    M = PD(i).M;
    fprintf('%6.3g %6.3g %8.2f %8.3f %8.3f %10s %10.3f\n', ...
        PD(i).Kp, PD(i).Kd, M.OS, M.tp, M.tr, ...
        tern(isnan(M.ts),'—',sprintf('%.3f',M.ts)), M.ess);
end

%% ------------------------ Speed Control + Speed Results: SPEED CONTROL (varying Kp) ------------------------
sFiles = dir(fullfile(dataDir,'closedloop-360-90-1000_*data.txt'));
S = struct([]);

for i = 1:numel(sFiles)
    fn = sFiles(i).name;
    tok = regexp(fn,'closedloop-360-90-1000_([0-9.]+)data\.txt','tokens','once');
    if isempty(tok), continue; end
    Kp = str2double(tok{1});

    D = loadECP(fullfile(sFiles(i).folder, fn));
    tt_raw = D(:,2);
    [tt, uniqIdx] = unique(tt_raw,'stable');
    D = D(uniqIdx,:);

    r_deg = D(:,3)*DEG_PER_COUNT;
    y_deg = D(:,ENC_COL)*DEG_PER_COUNT;

    % isolate forward ramp only (avoid return-to-zero part)
    i0   = find(r_deg > 0, 1, 'first');
    iEnd = find(r_deg >= 0.99*max(r_deg), 1, 'first');
    if isempty(i0) || isempty(iEnd) || iEnd <= i0
        continue;
    end
    sl = i0:iEnd;

    tseg = tt(sl) - tt(sl(1));
    r_vel = smoothdata(gradient(r_deg(sl))./gradient(tseg), 'movmedian', 9);
    y_vel = smoothdata(gradient(y_deg(sl))./gradient(tseg), 'movmedian', 9);

    S(end+1).Kp = Kp; %#ok<SAGROW>
    S(end).t = tseg;
    S(end).r = r_vel;
    S(end).y = y_vel;
end

if isempty(S), error('No speed-control files found (closedloop-360-90-1000_*data.txt).'); end

[~,idx] = sort([S.Kp]); S = S(idx);

% Figure 4 (Speed Control)
figure('Name','Figure 4 - Speed Control Speed control overlay (varying Kp)');
hold on; grid on;
for i = 1:numel(S)
    plot(S(i).t, S(i).y, 'DisplayName', sprintf('Kp=%.3g', S(i).Kp));
end
plot(S(1).t, S(1).r, 'k--', 'DisplayName', 'Reference speed (from command)');
xlabel('Time (s)'); ylabel('Speed (deg/s)');
title('Speed Control: Speed control response for different Kp');
legend('Location','best');

%% ------------------------ Pole Analysis: CLOSED-LOOP TF + POLES ------------------------
% Using the identified plant: G(s)=0.6/(J s^2 + c s)
s = tf('s');
G = 0.6/(J*s^2 + c*s);

% Closed-loop for PD/velocity feedback:
% T(s)= (Kp*G)/(1 + (Kp + Kd*s)*G)
% Characteristic: J s^2 + (c + 0.6 Kd)s + 0.6 Kp = 0

% Choose the same gains you tested in the lab:
Kp_vals  = [0.005 0.01 0.03];
Kd_vals  = [0.002 0.004 0.008];
Kp_fixed = 0.01;

% Figure 5: poles vs Kp (Kd=0)
figure('Name','Figure 5 - Pole Analysis Pole movement vs Kp (Kd=0)');
hold on; grid on;
for Kp = Kp_vals
    T = (Kp*G)/(1 + (Kp + 0*s)*G);
    p = pole(T);
    plot(real(p), imag(p), 'x', 'DisplayName', sprintf('Kp=%.3g',Kp));
end
xlabel('Real axis'); ylabel('Imag axis');
title('Pole Analysis: Closed-loop poles vs Kp (P control)');
legend('Location','best');

% Figure 6: poles vs Kd (Kp fixed)
figure('Name','Figure 6 - Pole Analysis Pole movement vs Kd (Kp=0.01)');
hold on; grid on;
for Kd = Kd_vals
    T = (Kp_fixed*G)/(1 + (Kp_fixed + Kd*s)*G);
    p = pole(T);
    plot(real(p), imag(p), 'x', 'DisplayName', sprintf('Kd=%.3g',Kd));
end
xlabel('Real axis'); ylabel('Imag axis');
title('Pole Analysis: Closed-loop poles vs Kd (PD / velocity feedback), Kp=0.01');
legend('Location','best');

disp('All figures generated. Copy/paste them into the report template in the indicated slots.');

%% ------------------------ LOCAL FUNCTIONS ------------------------
function D = loadECP(path)
    raw = fileread(path);
    i1 = strfind(raw,'[');
    i2 = strfind(raw,']');
    if isempty(i1) || isempty(i2)
        error('Could not find matrix brackets in file: %s', path);
    end
    block = raw(i1(1):i2(end));
    block = strrep(block,';','\n');
    block = strrep(block,'[','');
    block = strrep(block,']','');
    nums = textscan(block,'%f %f %f %f %f %f','CollectOutput',true);
    D = nums{1};
end

function sl = firstStepSlice(t, r_deg)
    rmax = max(r_deg);
    iStart = find(r_deg >= 0.1*rmax, 1, 'first');
    if isempty(iStart), sl = 1:numel(t); return; end
    iEnd = find(r_deg(iStart:end) <= 0.5*rmax, 1, 'first'); % return step begins
    if isempty(iEnd)
        sl = iStart:numel(t);
    else
        sl = iStart:(iStart + iEnd - 2);
    end
end

function S = stepMetrics(t, y, r, riseLims, settleTol)
    n = numel(t);
    tail = max(5, round(0.05*n));
    rFinal = median(r(end-tail+1:end));
    yFinal = median(y(end-tail+1:end));
    yPeak  = max(y);

    if abs(rFinal) < 1e-9
        OS = NaN;
    else
        OS = max(0,(yPeak - rFinal)/abs(rFinal))*100;
    end
    [~,iPk] = max(y);
    tPeak = t(iPk);

    y10 = riseLims(1)*rFinal;
    y90 = riseLims(2)*rFinal;
    i10 = find(y >= y10, 1, 'first');
    i90 = find(y >= y90, 1, 'first');
    if isempty(i10) || isempty(i90) || i90<=i10
        tRise = NaN;
    else
        tRise = t(i90) - t(i10);
    end

    band = settleTol*abs(rFinal);
    tSettle = NaN;
    if band > 1e-9
        inside = abs(y - rFinal) <= band;
        for k = 1:n
            if inside(k) && all(inside(k:end))
                tSettle = t(k);
                break;
            end
        end
    end

    ess = rFinal - yFinal;

    S = struct('OS',OS,'tp',tPeak,'tr',tRise,'ts',tSettle,'ess',ess,...
               'rFinal',rFinal,'yFinal',yFinal,'yPeak',yPeak);
end

function slope = localSlope(t, y, idx, window)
    % Robust least-squares slope on a local time window
    t0 = t(idx);
    mask = (t>=t0-window) & (t<=t0+window);

    tt = t(mask); yy = y(mask);
    tt = tt(:); yy = yy(:);

    if numel(tt) < 2
        slope = NaN;
        return;
    end

    A = [tt, ones(size(tt))];
    coeff = A \ yy;   % coeff(1)=slope
    slope = coeff(1);
end

function out = tern(cond, a, b)
    if cond, out = a; else, out = b; end
end
