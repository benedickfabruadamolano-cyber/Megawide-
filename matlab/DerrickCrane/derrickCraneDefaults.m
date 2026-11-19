function in = derrickCraneDefaults(supportType)
%DERRICKCRANEDEFAULTS  Default inputs, taken from the Excel template.
%   in = derrickCraneDefaults('Beam')  -> "Derrick Crane Beam" sheet (TEG)
%   in = derrickCraneDefaults('Slab')  -> "Derrick Crane Slab" sheet (Lancaster T1)

    if nargin < 1, supportType = 'Beam'; end
    in = struct();
    in.supportType = supportType;
    in.basis   = 'template';           % 'template' | 'refined'
    in.crane   = 'Top Sky Derrick TD3030-16';

    % ---- Crane data (TD3030-16, 30 m jib, 3.85 m fixing angle) ----------
    in.Pc  = 454;      % kN, max compression (corner D, in service)
    in.Pt  = 222;      % kN, max tension / uplift (corner A, in service)
    in.Pb  = 116;      % kN, side corners B & C (in service, for FBD)
    in.aSide = 3.85;   % m, fixing-angle side; diagonal = 5.445 m
    in.craneWt_t = 23.4;   % t, self weight
    in.cwWt_t    = 6.7;    % t, counterweight
    in.hook_t    = 3.0;    % t, rated load at 30 m
    in.hookPct   = 0;      % % of hook load included in seismic weight

    % ---- Materials ------------------------------------------------------
    in.fc  = 42;   in.fy = 415;          % MPa
    in.fyPlate = 248;                    % MPa (A36)
    in.fnv = 165;  in.fnt = 310;         % MPa (A307)
    in.fm  = 21;                         % MPa, 1-day non-shrink mortar

    % ---- Load factors (template) ---------------------------------------
    in.kt  = 1.25*1.25;                  % factor on Pt (1.25 impact x 1.25 LF)
    in.kEQ = 1.0;                        % crane factor in EQ combinations

    % ---- Earthquake (NSCP 2015) ----------------------------------------
    in.useEQ    = true;
    in.eqMethod = 'static';              % 'static' | 'simplified' | 'equipment'
    in.Z = 0.4;  in.soil = 'SD';  in.source = 'A';  in.dist_km = 10;
    in.I = 1.0;  in.R = 2.9;             % "other self-supporting structures"
    in.Ct = 0.0853; in.hn = 9.2; in.Tuser = 0;
    in.ap = 2.5; in.Rp = 3.0; in.hx = 30; in.hr = 30;
    in.hE = 3.0;                         % m  <-- USER: point of action above base

    % ---- Plate & anchor bolts ------------------------------------------
    in.tp = 0.025;  in.db = 32;

    % ---- Beam ----------------------------------------------------------
    in.Lb = 6.4;  in.b = 300;  in.h = 600;  in.cover = 40;
    in.dbar = 25; in.nBot = 8; in.nTop = 8;
    in.ds = 16;   in.s = 150;  in.legsSt = 1;

    % ---- Slab ----------------------------------------------------------
    in.ts = 0.2;  in.Pcap = 75*4/5.5;  in.Pscap = 19;

    if strcmpi(supportType, 'Beam')
        in.project = 'Taft East Gate (TEG)';
        in.lp = 1.0; in.wp = 1.0; in.nLegs = 4;
        in.kc = 1.25*1.25;               % beam sheet: 1.25*1.25*Pc
    else
        in.project = 'Lancaster Tower 1';
        in.lp = 1.2; in.wp = 1.2; in.nLegs = 6;
        in.kc = 1.25;                    % slab sheet: 1.25*Pc
    end
end
