function R = derrickCraneCalc(in)
%DERRICKCRANECALC  Shoring-support design of a derrick crane (beam or slab).
%
%   R = derrickCraneCalc(in) reproduces the "Derrick Crane Support Design
%   Note" Excel template (sheets "Derrick Crane Beam" / "Derrick Crane Slab")
%   and adds an NSCP 2015 earthquake check whose lateral force acts at a
%   user-defined height hE above the crane base.
%
%   Use derrickCraneDefaults('Beam') or derrickCraneDefaults('Slab') to get a
%   fully populated input struct.  Units: kN, m, MPa, mm (as in the template).
%
%   Basis 'template' = formulas exactly as in the Excel sheet.
%   Basis 'refined'  = code-consistent alternatives (see README).

    g = 9.81;  rep = {};
    isBeam    = strcmpi(in.supportType, 'Beam');
    isRefined = strcmpi(in.basis, 'refined');

    rep = addl(rep, '=====================================================================');
    rep = addl(rep, ' DERRICK CRANE SHORING SUPPORT DESIGN  -  %s SUPPORT', upper(in.supportType));
    rep = addl(rep, ' Project: %s    Crane: %s', in.project, in.crane);
    rep = addl(rep, ' Calculation basis: %s', upper(in.basis));
    rep = addl(rep, '=====================================================================');

    % ------------------------------------------------------------------
    % I. Dead load (steel plate / mortar pad)  - template: l*w*t*7850*9.81
    % ------------------------------------------------------------------
    Pd = in.lp * in.wp * in.tp * 7850 * g / 1000;                 % kN
    rep = addl(rep, '');
    rep = addl(rep, 'IV. LOAD CONSIDERATION');
    rep = addl(rep, '  Plate / pad self weight Pd = %.3f x %.3f x %.3f x 7850 x 9.81/1000 = %.3f kN', ...
               in.lp, in.wp, in.tp, Pd);
    rep = addl(rep, '  Crane compression Pc = %.1f kN    Crane tension (uplift) Pt = %.1f kN', in.Pc, in.Pt);

    % ------------------------------------------------------------------
    % II. Earthquake (NSCP 2015) - force V acting at hE above the base
    % ------------------------------------------------------------------
    a     = in.aSide;               % fixing-angle (square) side, m
    Ldiag = a * sqrt(2);            % distance between reaction corners A-D
    Wt    = in.craneWt_t + in.cwWt_t + in.hookPct/100 * in.hook_t;  % tonnes
    W     = Wt * g;                                              % kN

    S = struct('V',0,'coef',0,'gov','(earthquake not included)','lines',{{}}, ...
               'Na',NaN,'Nv',NaN,'Ca',NaN,'Cv',NaN,'T',NaN);
    V = 0; ME = 0; dR = 0; dRorth = 0; Hcorner = 0;
    if in.useEQ
        sp = struct('method',in.eqMethod,'Z',in.Z,'soil',in.soil,'source',in.source, ...
                    'dist_km',in.dist_km,'I',in.I,'R',in.R,'Ct',in.Ct,'hn',in.hn, ...
                    'Tuser',in.Tuser,'ap',in.ap,'Rp',in.Rp,'hx',in.hx,'hr',in.hr,'W',W);
        S  = nscpSeismic(sp);
        V  = S.V;
        ME = V * in.hE;                       % overturning moment at base
        dR     = ME / Ldiag;                  % EQ along jib (A-D diagonal) - governs
        dRorth = ME / (2*a);                  % EQ parallel to a fixing-angle side
        Hcorner = V / 4;                      % base shear shared by 4 corners
        rep = addl(rep, '');
        rep = addl(rep, '  EARTHQUAKE LOAD (NSCP 2015 Sec. 208) - method: %s', upper(in.eqMethod));
        rep = addl(rep, '  Seismic weight = crane %.2f t + counterweight %.2f t + %.0f%% of hook %.2f t = %.2f t', ...
                   in.craneWt_t, in.cwWt_t, in.hookPct, in.hook_t, Wt);
        for k = 1:numel(S.lines), rep = addl(rep, '    %s', S.lines{k}); end
        rep = addl(rep, '  Point of action above base (USER INPUT) hE = %.3f m', in.hE);
        rep = addl(rep, '  Overturning moment  M_E = V x hE = %.2f x %.3f = %.2f kN-m', V, in.hE, ME);
        rep = addl(rep, '  Fixing angle a = %.3f m  ->  diagonal L'' = a*sqrt(2) = %.3f m', a, Ldiag);
        rep = addl(rep, '  EQ along jib (A-D):   dR = M_E / L''  = %.2f kN   (governs)', dR);
        rep = addl(rep, '  EQ along side:        dR = M_E / (2a) = %.2f kN', dRorth);
        rep = addl(rep, '  Horizontal shear per corner H = V/4 = %.2f kN', Hcorner);
    else
        rep = addl(rep, '  Earthquake load: NOT INCLUDED (template gravity combinations only)');
    end

    % ------------------------------------------------------------------
    % III. Load combinations
    % ------------------------------------------------------------------
    Tu1 = in.kt * in.Pt;                                     % template
    Pu1 = 1.4 * Pd;
    Pu2 = 1.2 * Pd + in.kc * in.Pc;
    Tu3 = 0;  Pu3 = 0;
    if in.useEQ
        Tu3 = in.kEQ * in.Pt + dR - 0.9 * Pd;                % 0.9D + E (+ crane)
        Pu3 = 1.2 * Pd + in.kEQ * in.Pc + dR;                % 1.2D + E + f1*crane
    end
    [Tu, iT] = max([Tu1 Tu3]);
    [Pu, iP] = max([Pu1 Pu2 Pu3]);
    tName = {'Tu = kt*Pt','Tu = kEQ*Pt + dR - 0.9Pd'};
    pName = {'Pu = 1.4Pd','Pu = 1.2Pd + kc*Pc','Pu = 1.2Pd + kEQ*Pc + dR'};

    rep = addl(rep, '');
    rep = addl(rep, 'V. ANALYSIS AND DESIGN - LOAD COMBINATIONS');
    rep = addl(rep, '  Tension:      Tu1 = %.4f x %.1f = %.3f kN', in.kt, in.Pt, Tu1);
    rep = addl(rep, '  Compression:  Pu1 = 1.4 x %.3f = %.3f kN', Pd, Pu1);
    rep = addl(rep, '                Pu2 = 1.2 x %.3f + %.4f x %.1f = %.3f kN', Pd, in.kc, in.Pc, Pu2);
    if in.useEQ
        rep = addl(rep, '  EQ tension:   Tu3 = %.2f x %.1f + %.2f - 0.9 x %.3f = %.3f kN', in.kEQ, in.Pt, dR, Pd, Tu3);
        rep = addl(rep, '  EQ compr.:    Pu3 = 1.2 x %.3f + %.2f x %.1f + %.2f = %.3f kN', Pd, in.kEQ, in.Pc, dR, Pu3);
    end
    rep = addl(rep, '  GOVERNING  Tu = %.3f kN  (%s)', Tu, tName{iT});
    rep = addl(rep, '  GOVERNING  Pu = %.3f kN  (%s)', Pu, pName{iP});

    % ------------------------------------------------------------------
    % IV. Anchor bolt checks (common to both supports)
    % ------------------------------------------------------------------
    Ab   = pi * in.db^2 / 4;                                  % mm2 / leg
    Tcap = 0.75 * Ab * in.fnt * in.nLegs / 1000;              % kN
    Vcap = 0.75 * Ab * in.fnv * in.nLegs / 1000;              % kN
    frv  = Hcorner * 1000 / (in.nLegs * Ab);                  % MPa
    fntp = min(in.fnt, max(0, 1.3*in.fnt - in.fnt/(0.75*in.fnv)*frv));
    TcapI = 0.75 * Ab * fntp * in.nLegs / 1000;

    rows = {};
    rep = addl(rep, '');
    rep = addl(rep, '  CHECK BOLT CAPACITY  (dia %g mm, %g legs, A307)', in.db, in.nLegs);
    rep = addl(rep, '    Tcap = 0.75 x Ab x fnt x n = 0.75 x %.1f x %g x %g /1000 = %.3f kN', Ab, in.fnt, in.nLegs, Tcap);
    rep = addl(rep, '    DCR = Tu/Tcap = %.3f / %.3f = %.4f', Tu, Tcap, Tu/Tcap);
    rows(end+1,:) = {'Bolt tension', Tu, Tcap, 'kN', Tu/Tcap};
    if in.useEQ
        rep = addl(rep, '    Shear: Vcap = 0.75 x Ab x fnv x n = %.3f kN, H = %.3f kN, DCR = %.4f', Vcap, Hcorner, Hcorner/Vcap);
        rep = addl(rep, '    Tension+shear (AISC J3.7): f''nt = %.1f MPa -> Tcap'' = %.3f kN, DCR = %.4f', fntp, TcapI, Tu/max(TcapI,eps));
        rows(end+1,:) = {'Bolt shear (EQ)', Hcorner, Vcap, 'kN', Hcorner/Vcap};
        rows(end+1,:) = {'Bolt tension+shear', Tu, TcapI, 'kN', Tu/max(TcapI,eps)};
    end

    % ------------------------------------------------------------------
    % V. Support-specific checks
    % ------------------------------------------------------------------
    B = struct();  SL = struct();
    if isBeam
        % --- Mortar bearing ---
        Am = in.lp * in.wp;
        fu = Pu / (Am * 1000);
        rep = addl(rep, '');
        rep = addl(rep, '  CHECK COMPRESSION (non-shrink mortar)');
        rep = addl(rep, '    Am = %.3f m2,  Pu/Am = %.4f MPa,  capacity = %.1f MPa,  DCR = %.4f', Am, fu, in.fm, fu/in.fm);
        rows(end+1,:) = {'Mortar compression', fu, in.fm, 'MPa', fu/in.fm};

        % --- Shear ---
        d  = in.h - in.cover - in.ds - in.dbar/2;             % mm
        if isRefined, dv = d; else, dv = in.h; end
        Vc = 0.75 * 0.17 * in.b * dv * sqrt(in.fc) / 1000;
        Vs = 0.75 * in.legsSt * pi * in.ds^2 / 4 * in.fy * d / in.s / 1000;
        Vu = Pu / 2;
        rep = addl(rep, '');
        rep = addl(rep, '  CHECK SHEAR (beam %g x %g mm, stirrup %g mm @ %g mm, %g leg)', in.b, in.h, in.ds, in.s, in.legsSt);
        rep = addl(rep, '    d  = h - %g - ds - db/2 = %.1f mm', in.cover, d);
        rep = addl(rep, '    Vc = 0.75 x 0.17 x sqrt(fc) x b x %s = %.3f kN', ifelse(isRefined,'d','h'), Vc);
        rep = addl(rep, '    Vs = 0.75 x Av x fy x d/s = %.3f kN', Vs);
        rep = addl(rep, '    Vu = Pu/2 = %.3f kN,   DCR = Vu/(Vc+Vs) = %.4f', Vu, Vu/(Vc+Vs));
        rows(end+1,:) = {'Beam shear', Vu, Vc+Vs, 'kN', Vu/(Vc+Vs)};

        % --- Flexure ---
        if isRefined
            Mpos = Pu * in.Lb / 8;   Mneg = Pu * in.Lb / 8;   mtxt = 'PL/8 (fixed-fixed, point load at mid-span)';
        else
            Mpos = Pu * in.Lb / 24;  Mneg = 2 * Mpos;         mtxt = 'Mu+ = PuLb/24, Mu- = PuLb/12 (template)';
        end
        AsB = pi * in.dbar^2 / 4 * in.nBot;
        AsT = pi * in.dbar^2 / 4 * in.nTop;
        if isRefined
            aB = AsB*in.fy/(0.85*in.fc*in.b);  aT = AsT*in.fy/(0.85*in.fc*in.b);
            McapP = 0.9 * AsB * in.fy * (d - aB/2) / 1e6;
            McapN = 0.9 * AsT * in.fy * (d - aT/2) / 1e6;
        else
            McapP = 0.9 * AsB * in.fy * d / 1e6;
            McapN = 0.9 * AsT * in.fy * d / 1e6;
        end
        rep = addl(rep, '');
        rep = addl(rep, '  CHECK FLEXURE  (Lb = %.2f m; %s)', in.Lb, mtxt);
        rep = addl(rep, '    Mu+ = %.3f kN-m   Mcap+ = %.3f kN-m (%g-%gmm bot)  DCR = %.4f', Mpos, McapP, in.nBot, in.dbar, Mpos/McapP);
        rep = addl(rep, '    Mu- = %.3f kN-m   Mcap- = %.3f kN-m (%g-%gmm top)  DCR = %.4f', Mneg, McapN, in.nTop, in.dbar, Mneg/McapN);
        rows(end+1,:) = {'Beam flexure (+)', Mpos, McapP, 'kN-m', Mpos/McapP};
        rows(end+1,:) = {'Beam flexure (-)', Mneg, McapN, 'kN-m', Mneg/McapN};
        B = struct('d',d,'Vc',Vc,'Vs',Vs,'Vu',Vu,'Mpos',Mpos,'Mneg',Mneg,'McapP',McapP,'McapN',McapN);
    else
        % --- Slab shear (pull-out under uplift) ---
        if isRefined
            dS = in.ts - 0.03;
            bw = 2*(in.lp + dS) + 2*(in.wp + dS);
            VcapS = 0.75 * 0.33 * sqrt(in.fc) * bw * dS * 1000;
            stxt = sprintf('bo = 2(l+d)+2(w+d) = %.3f m, d = %.3f m, Vcap = 0.75x0.33xsqrt(fc)xbo x d', bw, dS);
        else
            bw = 2 * in.lp * in.wp;
            VcapS = 0.75 * 0.17 * sqrt(in.fc) * bw * in.ts * 1000;
            stxt = sprintf('bw = 2 x l x w = %.3f (template), Vcap = 0.75x0.17xsqrt(fc)x ts x bw', bw);
        end
        rep = addl(rep, '');
        rep = addl(rep, '  CHECK SLAB CAPACITY (ts = %.3f m)', in.ts);
        rep = addl(rep, '    %s', stxt);
        rep = addl(rep, '    Vcap = %.3f kN,  DCR = Tu/Vcap = %.4f', VcapS, Tu/VcapS);
        rows(end+1,:) = {'Slab shear (uplift)', Tu, VcapS, 'kN', Tu/VcapS};

        % --- Bearing / back-propping ---
        nFl  = ceil(Pu / in.Pcap - 1e-9);
        nSh  = ceil(Pu / in.Pscap - 1e-9);
        step = ceil(in.Pcap / in.Pscap - 1e-9);
        perFloor = nSh;
        k = 1;
        while k <= max(nFl-1, 0) && (nSh - k*step) > 0
            perFloor(end+1) = nSh - k*step; %#ok<AGROW>
            k = k + 1;
        end
        rep = addl(rep, '');
        rep = addl(rep, '  CHECK BEARING / BACK-PROPPING');
        rep = addl(rep, '    Pu = %.3f kN,  slab capacity per floor Pcap = %.3f kN', Pu, in.Pcap);
        rep = addl(rep, '    Required floors n = ROUNDUP(Pu/Pcap) = %d', nFl);
        rep = addl(rep, '    Shore capacity = %.1f kN -> shores required = ROUNDUP(Pu/Pscap) = %d pcs', in.Pscap, nSh);
        for k = 2:numel(perFloor)
            rep = addl(rep, '    Minimum shoring for floor n-%d = %d pcs', k-1, perFloor(k));
        end
        rows(end+1,:) = {'Shoring (per prop)', Pu/nSh, in.Pscap, 'kN', Pu/nSh/in.Pscap};
        SL = struct('bw',bw,'Vcap',VcapS,'nFloors',nFl,'nShores',nSh,'perFloor',perFloor);
    end

    % ------------------------------------------------------------------
    % Corner reactions for the base-plan FBD
    % ------------------------------------------------------------------
    corner.serv = struct('A',-in.Pt,'B',in.Pb,'C',in.Pb,'D',in.Pc);
    corner.eq   = struct('A',-(in.kEQ*in.Pt + dR),'B',in.kEQ*in.Pb,'C',in.kEQ*in.Pb,'D',in.kEQ*in.Pc + dR);
    corner.eqBC = struct('B',in.kEQ*in.Pb + dR,'C',in.kEQ*in.Pb - dR);
    if in.useEQ
        rep = addl(rep, '');
        rep = addl(rep, '  CORNER REACTIONS WITH EQ (kN, + compression):');
        rep = addl(rep, '    EQ along jib  : A = %.1f   D = %.1f   B = C = %.1f', corner.eq.A, corner.eq.D, corner.eq.B);
        rep = addl(rep, '    EQ along B-C  : B = %.1f   C = %.1f  %s', corner.eqBC.B, corner.eqBC.C, ...
                   ifelse(corner.eqBC.C < 0, '(C goes into UPLIFT - check)', ''));
    end

    % ------------------------------------------------------------------
    dcr = cell2mat(rows(:,5));
    rep = addl(rep, '');
    rep = addl(rep, '  SUMMARY');
    for k = 1:size(rows,1)
        rep = addl(rep, '    %-22s DCR = %6.3f   %s', rows{k,1}, rows{k,5}, ifelse(rows{k,5} <= 1, 'OK', 'NOT OK'));
    end
    rep = addl(rep, '  Max DCR = %.3f  ->  %s', max(dcr), ifelse(max(dcr) <= 1, 'ADEQUATE', 'INADEQUATE'));

    R = struct('Pd',Pd,'Tu',Tu,'Pu',Pu,'Tu1',Tu1,'Tu3',Tu3,'Pu1',Pu1,'Pu2',Pu2,'Pu3',Pu3, ...
               'W',W,'Wt',Wt,'V',V,'ME',ME,'dR',dR,'dRorth',dRorth,'H',Hcorner, ...
               'a',a,'Ldiag',Ldiag,'hE',in.hE,'seis',S,'Tcap',Tcap,'Vcap',Vcap, ...
               'beam',B,'slab',SL,'corner',corner,'rows',{rows},'maxDCR',max(dcr), ...
               'ok',max(dcr) <= 1,'report',{rep},'in',in);
end

% ======================================================================
function rep = addl(rep, fmt, varargin)
    rep{end+1} = sprintf(fmt, varargin{:});
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
