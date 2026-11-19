function S = nscpSeismic(s)
%NSCPSEISMIC  Earthquake base shear per NSCP 2015 (Section 208, UBC-97 basis).
%
%   S = nscpSeismic(s)  where s is a struct with fields
%       method   : 'static' | 'simplified' | 'equipment'
%       Z        : seismic zone factor (0.4 = Zone 4, 0.2 = Zone 2)
%       soil     : 'SA' 'SB' 'SC' 'SD' 'SE'
%       source   : seismic source type 'A' 'B' 'C'
%       dist_km  : closest distance to known seismic source (km)
%       I        : importance factor (I or Ip)
%       R        : response modification factor (static / simplified)
%       Ct       : period coefficient (static), T = Ct*hn^(3/4)
%       hn       : height of the structure (m) used for T
%       Tuser    : user period (s); <= 0 means compute from Ct*hn^(3/4)
%       ap, Rp   : component amplification / response factor (equipment)
%       hx, hr   : height of attachment / roof height (m) (equipment)
%       W        : seismic weight (kN)
%
%   Returns S with Na, Nv, Ca, Cv, T, V (kN), coef (= V/W), governing
%   equation text and a cell array of report lines.
%
%   Equations (verify numbering against your NSCP 2015 copy):
%     Static lateral force procedure:
%       V    = Cv*I*W/(R*T)          (Eq. 208-8)
%       Vmax = 2.5*Ca*I*W/R          (Eq. 208-9)
%       Vmin = 0.11*Ca*I*W           (Eq. 208-10)
%       Vmin = 0.8*Z*Nv*I*W/R        (Eq. 208-11, Zone 4 only)
%     Simplified static:
%       V    = 3*Ca*W/R
%     Equipment supported by a structure (crane sitting on a slab/roof):
%       Fp   = ap*Ca*Ip/Rp*(1+3*hx/hr)*Wp,  0.7*Ca*Ip*Wp <= Fp <= 4*Ca*Ip*Wp

    soilList = {'SA','SB','SC','SD','SE'};
    k = find(strcmpi(soilList, s.soil), 1);
    if isempty(k)
        error('nscpSeismic:soil', 'Soil profile must be SA..SE (SF needs site-specific study).');
    end

    % ---- Near-source factors (Tables 208-4 / 208-5) ----------------------
    switch upper(s.source)
        case 'A'
            NaV = [1.5 1.2 1.0];      NvV = [2.0 1.6 1.2 1.0];
        case 'B'
            NaV = [1.3 1.0 1.0];      NvV = [1.6 1.2 1.0 1.0];
        otherwise
            NaV = [1.0 1.0 1.0];      NvV = [1.0 1.0 1.0 1.0];
    end
    d  = min(max(s.dist_km, 2), 15);
    Na = interp1([2 5 10],    NaV, min(d, 10));
    Nv = interp1([2 5 10 15], NvV, d);

    % ---- Seismic coefficients (Tables 208-7 / 208-8) ---------------------
    isZone4 = s.Z >= 0.4 - 1e-9;
    if isZone4
        Ca = [0.32 0.40 0.40 0.44 0.36]; Ca = Ca(k) * Na;
        Cv = [0.32 0.40 0.56 0.64 0.96]; Cv = Cv(k) * Nv;
    else
        Na = 1.0; Nv = 1.0;
        Ca = [0.16 0.20 0.24 0.28 0.34]; Ca = Ca(k);
        Cv = [0.16 0.20 0.32 0.40 0.64]; Cv = Cv(k);
    end

    W = s.W;  I = s.I;
    S = struct('Na',Na,'Nv',Nv,'Ca',Ca,'Cv',Cv,'T',NaN,'V',0,'coef',0, ...
               'Vraw',NaN,'Vmax',NaN,'Vmin',NaN,'Vmin4',NaN,'gov','', ...
               'method',lower(s.method),'lines',{{}});
    L = {};
    L{end+1} = sprintf('Zone factor Z = %.2f, Soil = %s, Source type = %s, dist = %.1f km', ...
                       s.Z, upper(s.soil), upper(s.source), s.dist_km);
    L{end+1} = sprintf('Na = %.3f   Nv = %.3f   Ca = %.4f   Cv = %.4f', Na, Nv, Ca, Cv);
    L{end+1} = sprintf('Seismic weight W = %.2f kN', W);

    switch lower(s.method)
        case 'static'
            if isfield(s,'Tuser') && s.Tuser > 0
                T = s.Tuser;
                L{end+1} = sprintf('T (user) = %.3f s', T);
            else
                T = s.Ct * s.hn^0.75;
                L{end+1} = sprintf('T = Ct*hn^(3/4) = %.4f*%.2f^0.75 = %.3f s', s.Ct, s.hn, T);
            end
            Vraw = Cv*I*W/(s.R*T);
            Vmax = 2.5*Ca*I*W/s.R;
            Vmin = 0.11*Ca*I*W;
            if isZone4, Vmin4 = 0.8*s.Z*Nv*I*W/s.R; else, Vmin4 = 0; end
            V = min(Vraw, Vmax);  gov = 'V = Cv I W/(R T)  (Eq. 208-8)';
            if Vraw > Vmax, gov = 'Vmax = 2.5 Ca I W/R  (Eq. 208-9)'; end
            if Vmin > V,  V = Vmin;  gov = 'Vmin = 0.11 Ca I W  (Eq. 208-10)'; end
            if Vmin4 > V, V = Vmin4; gov = 'Vmin = 0.8 Z Nv I W/R  (Eq. 208-11)'; end
            L{end+1} = sprintf('V    = Cv I W/(R T) = %.4f*%.2f*%.2f/(%.2f*%.3f) = %.2f kN', Cv, I, W, s.R, T, Vraw);
            L{end+1} = sprintf('Vmax = 2.5 Ca I W/R  = %.2f kN', Vmax);
            L{end+1} = sprintf('Vmin = 0.11 Ca I W   = %.2f kN', Vmin);
            if isZone4
                L{end+1} = sprintf('Vmin = 0.8 Z Nv I W/R = %.2f kN  (Zone 4)', Vmin4);
            end
            S.T = T; S.Vraw = Vraw; S.Vmax = Vmax; S.Vmin = Vmin; S.Vmin4 = Vmin4;

        case 'simplified'
            V = 3*Ca*W/s.R;
            gov = 'V = 3 Ca W / R  (simplified static)';
            L{end+1} = sprintf('V = 3 Ca W/R = 3*%.4f*%.2f/%.2f = %.2f kN', Ca, W, s.R, V);

        case 'equipment'
            hr = max(s.hr, 1e-6);
            amp = 1 + 3*min(s.hx, hr)/hr;
            Fp  = s.ap*Ca*I/s.Rp*amp*W;
            Fmin = 0.7*Ca*I*W;  Fmax = 4.0*Ca*I*W;
            V = min(max(Fp, Fmin), Fmax);
            gov = 'Fp = ap Ca Ip/Rp (1+3hx/hr) Wp';
            if Fp < Fmin, gov = 'Fp,min = 0.7 Ca Ip Wp'; end
            if Fp > Fmax, gov = 'Fp,max = 4.0 Ca Ip Wp'; end
            L{end+1} = sprintf('(1+3hx/hr) = 1+3*%.2f/%.2f = %.3f', min(s.hx,hr), hr, amp);
            L{end+1} = sprintf('Fp = %.2f*%.4f*%.2f/%.2f*%.3f*%.2f = %.2f kN', s.ap, Ca, I, s.Rp, amp, W, Fp);
            L{end+1} = sprintf('Limits: 0.7CaIpWp = %.2f kN,  4.0CaIpWp = %.2f kN', Fmin, Fmax);
            S.Vraw = Fp; S.Vmin = Fmin; S.Vmax = Fmax;

        otherwise
            error('nscpSeismic:method', 'Unknown method "%s".', s.method);
    end

    S.V = V;  S.coef = V / max(W, eps);  S.gov = gov;
    L{end+1} = sprintf('DESIGN BASE SHEAR V = %.2f kN  (%.4f W)  <- %s', V, S.coef, gov);
    S.lines = L;
end
