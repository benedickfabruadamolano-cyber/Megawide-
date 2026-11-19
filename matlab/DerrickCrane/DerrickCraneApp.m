function DerrickCraneApp
%DERRICKCRANEAPP  GUI for derrick-crane shoring support design (beam / slab)
%   with NSCP 2015 earthquake base shear and free-body diagrams.
%
%   Run:  >> DerrickCraneApp
%   Requires MATLAB R2020b or newer (uifigure / uigridlayout).
%   Calculation engine: derrickCraneCalc.m, nscpSeismic.m, derrickCraneDefaults.m

    H   = struct();      % handles to UI components
    RES = [];            % last result

    clrTitle = [0.60 0.66 0.85];
    clrUser  = [1.00 0.97 0.70];      % highlight for user-defined EQ height

    % =================================================================
    %  FIGURE & MAIN LAYOUT
    % =================================================================
    fig = uifigure('Name','Derrick Crane Support Design  (NSCP 2015)', ...
                   'Position',[40 40 1560 900],'Color',[0.94 0.94 0.94]);
    main = uigridlayout(fig,[1 2],'ColumnWidth',{660,'1x'},'Padding',[8 8 8 8]);

    % ---------------- LEFT: inputs (scrollable) ----------------------
    left = uigridlayout(main,[3 2],'Scrollable','on', ...
        'RowHeight',{40,940,50},'ColumnWidth',{'1x','1x'}, ...
        'RowSpacing',8,'ColumnSpacing',8,'Padding',[4 4 4 4]);

    ttl = uilabel(left,'Text','Derrick Crane Support Design', ...
        'FontSize',18,'FontWeight','bold','FontColor','w', ...
        'BackgroundColor',clrTitle,'HorizontalAlignment','center');
    ttl.Layout.Row = 1; ttl.Layout.Column = [1 2];

    colA = uigridlayout(left,[5 1],'RowHeight',{pH(10),pH(6),pH(4),pH(5),34},'Padding',[0 0 0 0],'RowSpacing',8);
    colA.Layout.Row = 2; colA.Layout.Column = 1;
    colB = uigridlayout(left,[4 1],'RowHeight',{pH(16),pH(10),pH(3),'1x'},'Padding',[0 0 0 0],'RowSpacing',8);
    colB.Layout.Row = 2; colB.Layout.Column = 2;

    % ---- Panel: Support type & crane --------------------------------
    g = mkPanel(colA, 'Support Type & Crane', 10);
    H.support  = mkDrop(g,1,'Support type',{'Beam','Slab'},'Beam',@onSupportChanged);
    H.preset   = mkDrop(g,2,'Crane preset', ...
        {'TD3030-16  (3.85 m angle, L''=5.445)','TD3030-16  (L = 3.535 m)','Custom'}, ...
        'TD3030-16  (3.85 m angle, L''=5.445)',@onPreset);
    H.Pc     = mkNum(g,3,'Compression Pc (kN)',454,'Max corner compression, in service (D)');
    H.Pt     = mkNum(g,4,'Tension Pt (kN)',222,'Max corner uplift, in service (A)');
    H.Pb     = mkNum(g,5,'Side corners B/C (kN)',116,'Used for base-plan FBD / EQ along B-C');
    H.aSide  = mkNum(g,6,'Fixing angle side a (m)',3.85,'Diagonal L'' = a*sqrt(2) = distance between R1 and R2');
    H.craneWt_t = mkNum(g,7,'Crane self weight (t)',23.4,'');
    H.cwWt_t = mkNum(g,8,'Counterweight (t)',6.7,'');
    H.hook_t = mkNum(g,9,'Hook load (t)',3.0,'Rated load at working radius');
    H.hookPct= mkNum(g,10,'% hook load in seismic W',0,'Suspended loads are normally excluded (0%)');

    % ---- Panel: Materials -------------------------------------------
    g = mkPanel(colA, 'Material Specifications', 6);
    H.fc  = mkNum(g,1,'Concrete f''c (MPa)',42,'');
    H.fy  = mkNum(g,2,'Rebar fy (MPa)',415,'');
    H.fyPlate = mkNum(g,3,'Plate A36 fy (MPa)',248,'');
    H.fnv = mkNum(g,4,'Bolt A307 fnv (MPa)',165,'');
    H.fnt = mkNum(g,5,'Bolt A307 fnt (MPa)',310,'');
    H.fm  = mkNum(g,6,'Mortar 1-day (MPa)',21,'');

    % ---- Panel: Load factors ----------------------------------------
    g = mkPanel(colA, 'Load Combination', 4);
    H.basis = mkDrop(g,1,'Calculation basis',{'template','refined'},'template',[]);
    H.kc  = mkNum(g,2,'Factor on Pc, kc',1.5625,'Beam sheet: 1.25x1.25; Slab sheet: 1.25');
    H.kt  = mkNum(g,3,'Factor on Pt, kt',1.5625,'1.25 impact x 1.25 load factor');
    H.kEQ = mkNum(g,4,'Crane factor in EQ combo',1.0,'1.2D + 1.0E + f1*Crane / 0.9D + 1.0E');

    % ---- Panel: Plate & anchor --------------------------------------
    g = mkPanel(colA, 'Base Plate & U-Anchor Bolts', 5);
    H.lp = mkNum(g,1,'Plate length l (m)',1.0,'');
    H.wp = mkNum(g,2,'Plate width w (m)',1.0,'');
    H.tp = mkNum(g,3,'Plate thickness t (m)',0.025,'');
    H.db = mkNum(g,4,'Bolt diameter (mm)',32,'');
    H.nLegs = mkNum(g,5,'No. of bolt legs',4,'');

    % ---- Buttons ------------------------------------------------------
    gb = uigridlayout(colA,[1 3],'ColumnWidth',{'1x','1x','1x'},'RowHeight',{34},'Padding',[0 0 0 0]);
    uibutton(gb,'Text','Calculate','FontWeight','bold','BackgroundColor',[0.75 0.90 0.75],'ButtonPushedFcn',@(~,~)runCalc());
    uibutton(gb,'Text','Export Report','ButtonPushedFcn',@(~,~)exportReport());
    uibutton(gb,'Text','Reset','ButtonPushedFcn',@(~,~)resetDefaults());

    % ---- Panel: Earthquake ------------------------------------------
    g = mkPanel(colB, 'Earthquake Load (NSCP 2015)', 16);
    H.useEQ   = uicheckbox(g,'Text','Include earthquake','Value',true);
    H.useEQ.Layout.Row = 1; H.useEQ.Layout.Column = [1 2];
    H.eqMethod = mkDrop(g,2,'Method',{'static','simplified','equipment'},'static',@onMethod);
    H.zone   = mkDrop(g,3,'Seismic zone',{'Zone 4 (Z=0.40)','Zone 2 (Z=0.20)'},'Zone 4 (Z=0.40)',[]);
    H.soil   = mkDrop(g,4,'Soil profile',{'SA','SB','SC','SD','SE'},'SD',[]);
    H.source = mkDrop(g,5,'Seismic source type',{'A','B','C'},'A',[]);
    H.dist_km= mkNum(g,6,'Dist. to source (km)',10,'Closest distance to active fault');
    H.I      = mkNum(g,7,'Importance I / Ip',1.0,'');
    H.R      = mkNum(g,8,'R (static/simplified)',2.9,'Other self-supporting structures');
    H.Ct     = mkNum(g,9,'Ct (period)',0.0853,'0.0853 steel MRF; 0.0488 others');
    H.hn     = mkNum(g,10,'hn (m)',9.2,'Crane height for T = Ct hn^(3/4)');
    H.Tuser  = mkNum(g,11,'T user (s), 0 = auto',0,'');
    H.ap     = mkNum(g,12,'ap (equipment)',2.5,'1.0 rigid, 2.5 flexible');
    H.Rp     = mkNum(g,13,'Rp (equipment)',3.0,'');
    H.hx     = mkNum(g,14,'hx attachment ht (m)',30,'Height of slab where crane sits');
    H.hr     = mkNum(g,15,'hr roof height (m)',30,'');
    H.hE     = mkNum(g,16,'>> hE point of action (m)',3.0, ...
                     'USER INPUT: height above crane base where V acts');
    H.hE.BackgroundColor = clrUser; H.hE.FontWeight = 'bold';

    % ---- Panel: Beam --------------------------------------------------
    g = mkPanel(colB, 'RC Beam Support', 10);
    H.Lb   = mkNum(g,1,'Beam length Lb (m)',6.4,'');
    H.b    = mkNum(g,2,'Beam width b (mm)',300,'');
    H.h    = mkNum(g,3,'Beam depth h (mm)',600,'');
    H.cover= mkNum(g,4,'Clear cover (mm)',40,'');
    H.dbar = mkNum(g,5,'Main bar dia (mm)',25,'');
    H.nBot = mkNum(g,6,'Bottom bars (pcs)',8,'');
    H.nTop = mkNum(g,7,'Top bars (pcs)',8,'');
    H.ds   = mkNum(g,8,'Stirrup dia (mm)',16,'');
    H.s    = mkNum(g,9,'Stirrup spacing (mm)',150,'');
    H.legsSt = mkNum(g,10,'Stirrup legs',1,'Template uses 1 leg (conservative)');

    % ---- Panel: Slab --------------------------------------------------
    g = mkPanel(colB, 'RC Slab Support / Back-propping', 3);
    H.ts    = mkNum(g,1,'Slab thickness ts (m)',0.2,'');
    H.Pcap  = mkNum(g,2,'Slab capacity/floor (kN)',75*4/5.5,'Template: 75*4/5.5');
    H.Pscap = mkNum(g,3,'Shore capacity (kN)',19,'');

    % ---- Status ------------------------------------------------------
    H.status = uilabel(colB,'Text','Ready.  Press Calculate.','FontWeight','bold', ...
        'WordWrap','on','FontColor',[0.2 0.2 0.2]);

    % ---- bottom-left: project text -----------------------------------
    gp = uigridlayout(left,[1 4],'ColumnWidth',{70,'1x',50,'1x'},'Padding',[0 0 0 0]);
    gp.Layout.Row = 3; gp.Layout.Column = [1 2];
    uilabel(gp,'Text','Project:');
    H.project = uieditfield(gp,'text','Value','Taft East Gate (TEG)');
    uilabel(gp,'Text','Crane:');
    H.crane = uieditfield(gp,'text','Value','Top Sky Derrick TD3030-16');

    % ---------------- RIGHT: outputs ---------------------------------
    right = uigridlayout(main,[2 1],'RowHeight',{'1.25x','1x'},'Padding',[0 0 0 0]);
    tg1 = uitabgroup(right);
    t1 = uitab(tg1,'Title','Crane FBD (Elevation)');
    t2 = uitab(tg1,'Title','Base Plan / Corner Reactions');
    t3 = uitab(tg1,'Title','Support FBD');
    H.axCrane = uiaxes(uigridlayout(t1,[1 1],'Padding',[2 2 2 2]));
    H.axPlan  = uiaxes(uigridlayout(t2,[1 1],'Padding',[2 2 2 2]));
    g3 = uigridlayout(t3,[2 2],'Padding',[2 2 2 2],'RowHeight',{'1x','1x'});
    H.axS1 = uiaxes(g3); H.axS1.Layout.Row = 1; H.axS1.Layout.Column = [1 2];
    H.axS2 = uiaxes(g3); H.axS2.Layout.Row = 2; H.axS2.Layout.Column = 1;
    H.axS3 = uiaxes(g3); H.axS3.Layout.Row = 2; H.axS3.Layout.Column = 2;

    tg2 = uitabgroup(right);
    r1 = uitab(tg2,'Title','Design Checks');
    r2 = uitab(tg2,'Title','Seismic');
    r3 = uitab(tg2,'Title','Calculation Report');
    gr1 = uigridlayout(r1,[1 1],'Padding',[2 2 2 2]);
    H.tbl = uitable(gr1,'ColumnName',{'Check','Demand','Capacity','Unit','DCR','Status'}, ...
        'ColumnWidth',{190,100,100,60,80,90},'RowName',{});
    gr2 = uigridlayout(r2,[1 1],'Padding',[2 2 2 2]);
    H.tblEQ = uitable(gr2,'ColumnName',{'Parameter','Value','Remarks'}, ...
        'ColumnWidth',{200,120,'auto'},'RowName',{});
    gr3 = uigridlayout(r3,[1 1],'Padding',[2 2 2 2]);
    H.report = uitextarea(gr3,'FontName','Consolas','FontSize',11,'Editable','off');

    onMethod();
    runCalc();

    % =================================================================
    %  CALLBACKS
    % =================================================================
    function onSupportChanged(~,~)
        d = derrickCraneDefaults(H.support.Value);
        H.lp.Value = d.lp; H.wp.Value = d.wp; H.nLegs.Value = d.nLegs;
        H.kc.Value = d.kc; H.project.Value = d.project;
        H.status.Text = sprintf('%s template defaults applied (plate, bolt legs, kc).', H.support.Value);
        runCalc();
    end

    function onPreset(~,~)
        switch H.preset.Value
            case 'TD3030-16  (3.85 m angle, L''=5.445)'
                H.Pt.Value = 222; H.Pc.Value = 454; H.Pb.Value = 116; H.aSide.Value = 3.85;
            case 'TD3030-16  (L = 3.535 m)'
                H.Pt.Value = 409; H.Pc.Value = 633; H.Pb.Value = 116; H.aSide.Value = 3.535/sqrt(2);
        end
    end

    function onMethod(~,~)
        m = H.eqMethod.Value;
        H.R.Enable = onoff(~strcmp(m,'equipment'));
        for c = {H.Ct, H.hn, H.Tuser}, c{1}.Enable = onoff(strcmp(m,'static')); end
        for c = {H.ap, H.Rp, H.hx, H.hr}, c{1}.Enable = onoff(strcmp(m,'equipment')); end
    end

    function resetDefaults()
        d = derrickCraneDefaults(H.support.Value);
        fn = fieldnames(H);
        for k = 1:numel(fn)
            if isfield(d, fn{k}) && isNumField(H.(fn{k}))
                H.(fn{k}).Value = d.(fn{k});
            end
        end
        H.useEQ.Value = true; H.eqMethod.Value = 'static'; H.soil.Value = 'SD';
        H.source.Value = 'A'; H.zone.Value = 'Zone 4 (Z=0.40)'; H.basis.Value = 'template';
        onMethod(); runCalc();
    end

    % =================================================================
    function in = readInputs()
        in = derrickCraneDefaults(H.support.Value);
        fn = fieldnames(H);
        for k = 1:numel(fn)
            if isfield(in, fn{k}) && isNumField(H.(fn{k}))
                in.(fn{k}) = H.(fn{k}).Value;
            end
        end
        in.supportType = H.support.Value;
        in.basis    = H.basis.Value;
        in.useEQ    = H.useEQ.Value;
        in.eqMethod = H.eqMethod.Value;
        in.soil     = H.soil.Value;
        in.source   = H.source.Value;
        in.Z        = ifelse(startsWith(H.zone.Value,'Zone 4'), 0.4, 0.2);
        in.project  = H.project.Value;
        in.crane    = H.crane.Value;
    end

    function runCalc()
        try
            in  = readInputs();
            RES = derrickCraneCalc(in);
        catch err
            H.status.Text = ['Error: ' err.message]; H.status.FontColor = [0.8 0 0];
            return
        end
        fillTables(RES);
        H.report.Value = RES.report;
        drawCraneFBD(H.axCrane, RES);
        drawPlanFBD(H.axPlan, RES);
        axs = [H.axS1 H.axS2 H.axS3];
        if strcmpi(in.supportType,'Beam'), drawBeamFBD(axs, RES); else, drawSlabFBD(axs, RES); end
        if RES.ok
            H.status.Text = sprintf('ADEQUATE  -  max DCR = %.3f   |   V = %.1f kN @ hE = %.2f m', RES.maxDCR, RES.V, RES.hE);
            H.status.FontColor = [0 0.5 0];
        else
            H.status.Text = sprintf('INADEQUATE  -  max DCR = %.3f   |   V = %.1f kN @ hE = %.2f m', RES.maxDCR, RES.V, RES.hE);
            H.status.FontColor = [0.8 0 0];
        end
    end

    function fillTables(R)
        rows = R.rows;  n = size(rows,1);
        data = cell(n,6);
        for k = 1:n
            data(k,:) = {rows{k,1}, round(rows{k,2},3), round(rows{k,3},3), rows{k,4}, ...
                         round(rows{k,5},4), ifelse(rows{k,5}<=1,'OK','NOT OK')};
        end
        H.tbl.Data = data;
        removeStyle(H.tbl);
        for k = 1:n
            if rows{k,5} <= 1, c = [0.80 0.95 0.80]; else, c = [1.0 0.75 0.75]; end
            addStyle(H.tbl, uistyle('BackgroundColor',c), 'cell', [k 5; k 6]);
        end

        S = R.seis;  in = R.in;
        eq = {'Method', in.eqMethod, ''
              'Zone factor Z', in.Z, ''
              'Soil profile', in.soil, ''
              'Near-source Na', S.Na, 'Table 208-4'
              'Near-source Nv', S.Nv, 'Table 208-5'
              'Ca', S.Ca, 'Table 208-7'
              'Cv', S.Cv, 'Table 208-8'
              'Period T (s)', S.T, 'static method only'
              'Seismic weight W (kN)', R.W, sprintf('%.2f t', R.Wt)
              'Base shear V (kN)', R.V, S.gov
              'V / W', S.coef, ''
              'hE - point of action (m)', R.hE, 'USER INPUT'
              'Overturning M_E (kN-m)', R.ME, 'V x hE'
              'Diagonal L'' (m)', R.Ldiag, 'a x sqrt(2)'
              'dR along jib (kN)', R.dR, 'M_E / L'''
              'dR along side (kN)', R.dRorth, 'M_E / (2a)'
              'Shear per corner H (kN)', R.H, 'V / 4'};
        for k = 1:size(eq,1)
            if isnumeric(eq{k,2}), eq{k,2} = sprintf('%.4g', eq{k,2}); end
        end
        H.tblEQ.Data = eq;
    end

    function exportReport()
        if isempty(RES), return; end
        [f,p] = uiputfile('*.txt','Save calculation report', ...
            sprintf('DerrickCrane_%s_Report.txt', RES.in.supportType));
        if isequal(f,0), return; end
        fid = fopen(fullfile(p,f),'w');
        fprintf(fid,'%s\r\n',RES.report{:});
        fclose(fid);
        try
            exportgraphics(H.axCrane, fullfile(p,[f(1:end-4) '_CraneFBD.png']),'Resolution',200);
            exportgraphics(H.axPlan,  fullfile(p,[f(1:end-4) '_PlanFBD.png']),'Resolution',200);
            exportgraphics(H.axS1,    fullfile(p,[f(1:end-4) '_SupportFBD.png']),'Resolution',200);
        catch
        end
        H.status.Text = ['Report saved: ' fullfile(p,f)];
    end

    % =================================================================
    %  UI HELPERS
    % =================================================================
    function hpx = pH(nrows)
        hpx = 26*nrows + 34;          % panel height in pixels
    end

    function gg = mkPanel(parent, title, nrows)
        p  = uipanel(parent,'Title',title,'FontWeight','bold','BackgroundColor',[0.96 0.96 0.96]);
        gg = uigridlayout(p,[nrows 2],'ColumnWidth',{'1x',95}, ...
            'RowHeight',repmat({22},1,nrows),'RowSpacing',4,'Padding',[8 6 8 6]);
    end

    function ef = mkNum(gg, row, label, val, tip)
        lb = uilabel(gg,'Text',label); lb.Layout.Row = row; lb.Layout.Column = 1;
        ef = uieditfield(gg,'numeric','Value',val,'HorizontalAlignment','center');
        ef.Layout.Row = row; ef.Layout.Column = 2;
        if ~isempty(tip), ef.Tooltip = tip; lb.Tooltip = tip; end
    end

    function dd = mkDrop(gg, row, label, items, val, cb)
        lb = uilabel(gg,'Text',label); lb.Layout.Row = row; lb.Layout.Column = 1;
        dd = uidropdown(gg,'Items',items,'Value',val);
        dd.Layout.Row = row; dd.Layout.Column = 2;
        if ~isempty(cb), dd.ValueChangedFcn = cb; end
    end
end

% =====================================================================
%  FREE-BODY DIAGRAMS (local functions, take axes handles)
% =================================================================
function drawCraneFBD(ax, R)
    prepAx(ax, 'Derrick Crane - Free Body Diagram (elevation along jib)');
    L2 = R.Ldiag/2;  in = R.in;
    steel = [0.95 0.60 0.10];

    % base frame & slewing platform
    patch(ax,[-L2-0.3 L2+0.3 L2+0.3 -L2-0.3],[0 0 0.5 0.5],[0.85 0.55 0.15],'EdgeColor','k');
    patch(ax,[-0.9 0.9 0.9 -0.9],[0.5 0.5 1.5 1.5],steel,'EdgeColor','k');
    % counter-jib & counterweight
    plot(ax,[-3.6 0],[1.6 1.6],'-','Color','k','LineWidth',3);
    patch(ax,[-3.9 -3.2 -3.2 -3.9],[1.0 1.0 2.6 2.6],[0.5 0.5 0.5],'EdgeColor','k');
    text(ax,-3.55,2.85,'CW','HorizontalAlignment','center','FontSize',8);
    % mast (A-frame) to 9.2 m
    plot(ax,[0 0.2],[1.5 9.2],'-','Color',steel*0.8,'LineWidth',3);
    plot(ax,[-1.0 0.2],[1.5 9.2],'-','Color',steel*0.8,'LineWidth',2);
    % boom 30 m @ 15 deg
    th = 15*pi/180; p0 = [0.8 1.6]; tip = p0 + 30*[cos(th) sin(th)];
    plot(ax,[p0(1) tip(1)],[p0(2) tip(2)],'-','Color',steel,'LineWidth',4);
    plot(ax,[0.2 tip(1)],[9.2 tip(2)],'-','Color',[0.3 0.3 0.3],'LineWidth',1);
    plot(ax,[0.2 -3.6],[9.2 1.6],'-','Color',[0.3 0.3 0.3],'LineWidth',1);
    % hook
    plot(ax,[tip(1) tip(1)],[tip(2) tip(2)-3],'k-');
    arrow(ax,[tip(1) tip(2)-3],[tip(1) tip(2)-5.2],[0.2 0.2 0.2],0.7);
    text(ax,tip(1)+0.4,tip(2)-4.6,sprintf('Q = %.1f t',in.hook_t),'FontSize',9);

    % weight at CG
    arrow(ax,[0 5.0],[0 2.2],[0.1 0.3 0.8],0.6);
    text(ax,0.4,4.6,sprintf('W = %.1f kN',R.W),'Color',[0.1 0.3 0.8],'FontSize',9,'FontWeight','bold');

    % earthquake force at hE
    red = [0.85 0.1 0.1];
    if in.useEQ
        hE = R.hE;
        arrow(ax,[-8 hE],[-0.2 hE],red,0.7);
        text(ax,-8,hE+0.7,sprintf('V = %.1f kN',R.V),'Color',red,'FontWeight','bold','FontSize',10);
        % dimension hE
        plot(ax,[-9 -9],[0 hE],'-','Color',red); plot(ax,[-9.3 -8.7],[0 0],'-','Color',red);
        plot(ax,[-9.3 -8.7],[hE hE],'-','Color',red); plot(ax,[-9 -0.2],[hE hE],':','Color',red);
        text(ax,-9.3,hE/2,sprintf('hE = %.2f m',hE),'Color',red,'HorizontalAlignment','right','FontSize',9);
        % base shear
        arrow(ax,[L2+3.5 -0.25],[L2+0.4 -0.25],red,0.6);
        text(ax,L2+3.7,-0.25,sprintf('H = %.1f kN',R.V),'Color',red,'FontSize',9);
        text(ax,8,11.3,sprintf('M_E = V x hE = %.1f kN-m   ->   dR = M_E / L'' = %.1f kN',R.ME,R.dR), ...
            'Color',red,'FontSize',9,'FontWeight','bold','Interpreter','none');
    end

    % support reactions on crane
    arrow(ax,[-L2 0],[-L2 -2.4],[0.5 0 0.6],0.6);         % hold-down (tension)
    text(ax,-L2-0.2,-2.9,sprintf('R1 (A) = Tu = %.1f kN',R.Tu),'Color',[0.5 0 0.6], ...
        'HorizontalAlignment','right','FontSize',9,'FontWeight','bold');
    arrow(ax,[L2 -2.4],[L2 0],[0 0.45 0],0.6);            % compression
    text(ax,L2+0.2,-2.9,sprintf('R2 (D) = Pu = %.1f kN',R.Pu),'Color',[0 0.45 0], ...
        'FontSize',9,'FontWeight','bold');
    % L' dimension
    plot(ax,[-L2 L2],[-3.6 -3.6],'k-'); plot(ax,[-L2 -L2],[-3.8 -3.4],'k-'); plot(ax,[L2 L2],[-3.8 -3.4],'k-');
    text(ax,0,-4.1,sprintf('L'' = %.3f m',R.Ldiag),'HorizontalAlignment','center','FontSize',9);
    plot(ax,[-11 32],[0 0],'-','Color',[0.4 0.4 0.4]);
    axis(ax,'equal'); xlim(ax,[-13 33]); ylim(ax,[-4.8 12.2]);
    xlabel(ax,'m'); ylabel(ax,'m');
end

function drawPlanFBD(ax, R)
    prepAx(ax, 'Base Plan - Fixing Angle Corner Reactions (kN, + = compression)');
    L2 = R.Ldiag/2;
    P = struct('A',[-L2 0],'B',[0 L2],'C',[0 -L2],'D',[L2 0]);
    sq = [P.A; P.B; P.D; P.C; P.A];
    plot(ax,sq(:,1),sq(:,2),'--','Color',[0.6 0.6 0.6]);
    plot(ax,[P.A(1) P.D(1)],[0 0],'-','Color',[0.85 0.55 0.15],'LineWidth',6);
    plot(ax,[0 0],[P.C(2) P.B(2)],'-','Color',[0.85 0.55 0.15],'LineWidth',6);
    cs = R.corner.serv; ce = R.corner.eq; nm = {'A','B','C','D'};
    for k = 1:4
        p = P.(nm{k});
        patch(ax,p(1)+0.3*[-1 1 1 -1],p(2)+0.3*[-1 -1 1 1],[0.3 0.3 0.3]);
        txt = sprintf('%s\nService: %.0f\nWith EQ: %.0f', nm{k}, cs.(nm{k}), ce.(nm{k}));
        text(ax,p(1)+2.4*sign(p(1)),p(2)+1.6*sign(p(2)),txt,'HorizontalAlignment','center', ...
            'FontSize',9,'FontWeight','bold','Color',ifelse(ce.(nm{k})<0,[0.6 0 0.6],[0 0.4 0]));
    end
    arrow(ax,[L2+0.8 -L2],[L2+3.2 -L2],[0.2 0.2 0.2],0.4);
    text(ax,L2+0.8,-L2-0.5,'JIB direction','FontSize',9);
    if R.in.useEQ
        arrow(ax,[-L2-3.2 -L2],[-L2-0.8 -L2],[0.85 0.1 0.1],0.4);
        text(ax,-L2-3.2,-L2-0.5,sprintf('EQ: V = %.1f kN',R.V),'Color',[0.85 0.1 0.1],'FontSize',9);
        text(ax,-L2-4.3,L2+1.6,sprintf('EQ along B-C:\nB = %.0f,  C = %.0f kN', ...
            R.corner.eqBC.B, R.corner.eqBC.C),'FontSize',9, ...
            'Color',ifelse(R.corner.eqBC.C<0,[0.6 0 0.6],[0 0 0]));
    end
    text(ax,L2+4.3,L2+1.6,sprintf('a = %.3f m\nL'' = %.3f m',R.a,R.Ldiag),'HorizontalAlignment','right','FontSize',9);
    axis(ax,'equal'); xlim(ax,[-L2-4.6 L2+4.6]); ylim(ax,[-L2-3.0 L2+3.2]);
    set(ax,'XTick',[],'YTick',[]);
end

function drawBeamFBD(axs, R)
    B = R.beam; Lb = R.in.Lb; Pu = R.Pu;
    ax = axs(1);  prepAx(ax, sprintf('RC Beam FBD  (b x h = %g x %g mm,  Lb = %.2f m)', R.in.b, R.in.h, Lb));
    hb = 0.35;
    patch(ax,[0 Lb Lb 0],[0 0 hb hb],[0.8 0.8 0.8],'EdgeColor','k');
    for x0 = [0 Lb]                                         % fixed ends
        s = ifelse(x0==0,-1,1);
        plot(ax,[x0 x0],[-0.5 hb+0.5],'k-','LineWidth',2);
        for yy = -0.5:0.2:hb+0.4, plot(ax,[x0 x0+0.15*s],[yy yy+0.15],'k-'); end
    end
    arrow(ax,[Lb/2 hb+1.8],[Lb/2 hb],[0 0.45 0],0.25);
    text(ax,Lb/2+0.1,hb+1.6,sprintf('Pu = %.1f kN',Pu),'Color',[0 0.45 0],'FontWeight','bold','FontSize',9);
    arrow(ax,[0.25 -1.4],[0.25 0],[0.1 0.3 0.8],0.25);
    arrow(ax,[Lb-0.25 -1.4],[Lb-0.25 0],[0.1 0.3 0.8],0.25);
    text(ax,0.4,-1.2,sprintf('Pu/2 = %.1f',Pu/2),'Color',[0.1 0.3 0.8],'FontSize',9);
    text(ax,Lb-0.4,-1.2,sprintf('Pu/2 = %.1f',Pu/2),'Color',[0.1 0.3 0.8],'FontSize',9,'HorizontalAlignment','right');
    text(ax,0.3,hb+0.9,sprintf('M- = %.1f',B.Mneg),'FontSize',9,'Color',[0.6 0 0]);
    text(ax,Lb-0.3,hb+0.9,sprintf('M- = %.1f',B.Mneg),'FontSize',9,'Color',[0.6 0 0],'HorizontalAlignment','right');
    text(ax,Lb/2,-0.4,'Crane corner (R2) on plate','HorizontalAlignment','center','FontSize',8);
    axis(ax,'equal'); xlim(ax,[-0.8 Lb+0.8]); ylim(ax,[-1.8 hb+2.2]); set(ax,'YTick',[]);

    % shear diagram
    ax = axs(2); prepAx(ax, 'Shear Force Diagram (kN)');
    x = [0 0 Lb/2 Lb/2 Lb Lb]; v = [0 Pu/2 Pu/2 -Pu/2 -Pu/2 0];
    patch(ax,x,v,[0.6 0.75 0.95],'EdgeColor',[0.1 0.3 0.8]);
    plot(ax,[0 Lb],[0 0],'k-');
    text(ax,Lb/4,Pu/2,sprintf('%.1f',Pu/2),'VerticalAlignment','bottom','HorizontalAlignment','center');
    text(ax,3*Lb/4,-Pu/2,sprintf('%.1f',-Pu/2),'VerticalAlignment','top','HorizontalAlignment','center');
    xlim(ax,[0 Lb]); ylim(ax,[-0.75 0.75]*Pu); xlabel(ax,'x (m)');

    % moment diagram
    ax = axs(3); prepAx(ax, 'Bending Moment Diagram (kN-m)');
    x = [0 Lb/2 Lb]; m = [-B.Mneg B.Mpos -B.Mneg];
    patch(ax,[0 x Lb],[0 m 0],[0.95 0.75 0.6],'EdgeColor',[0.8 0.3 0]);
    plot(ax,[0 Lb],[0 0],'k-');
    plot(ax,[0 Lb],[B.McapP B.McapP],'g--'); plot(ax,[0 Lb],-[B.McapN B.McapN],'g--');
    text(ax,Lb/2,B.Mpos,sprintf('Mu+ = %.1f',B.Mpos),'VerticalAlignment','bottom','HorizontalAlignment','center');
    text(ax,0.05,-B.Mneg,sprintf('Mu- = %.1f',B.Mneg),'VerticalAlignment','top');
    text(ax,Lb,B.McapP,'\phiMn+','HorizontalAlignment','right','VerticalAlignment','bottom','Color',[0 0.5 0]);
    xlim(ax,[0 Lb]); ylim(ax,1.15*max([B.McapP B.McapN B.Mneg])*[-1 1]); xlabel(ax,'x (m)');
end

function drawSlabFBD(axs, R)
    in = R.in; SL = R.slab;
    % plan of plate, bolts and shear perimeter
    ax = axs(1); prepAx(ax, sprintf('Slab - Plate %.2f x %.2f m, %g U-bolt legs, shear perimeter', in.lp, in.wp, in.nLegs));
    l = in.lp; w = in.wp;
    patch(ax,[-l l l -l]/2,[-w -w w w]/2,[0.75 0.75 0.8],'EdgeColor','k');
    n = in.nLegs; th = linspace(0,2*pi,n+1); th(end) = [];
    plot(ax,0.35*l*cos(th+pi/4),0.35*w*sin(th+pi/4),'ko','MarkerFaceColor','k','MarkerSize',8);
    if strcmpi(in.basis,'refined'), e = (in.ts-0.03)/2; else, e = 0; end
    plot(ax,[-l-2*e l+2*e l+2*e -l-2*e -l-2*e]/2,[-w-2*e -w-2*e w+2*e w+2*e -w-2*e]/2,'r--','LineWidth',1.5);
    text(ax,l/2+0.15,0,sprintf('Tu = %.1f kN (uplift)\nVcap = %.1f kN\nPu = %.1f kN',R.Tu,SL.Vcap,R.Pu), ...
        'FontSize',9,'FontWeight','bold');
    axis(ax,'equal'); xlim(ax,[-l 1.6*l]); ylim(ax,[-0.7 0.7]*w); set(ax,'XTick',[],'YTick',[]);

    % elevation of back-propped floors
    ax = axs(2); prepAx(ax, sprintf('Back-propping: %d floors, %d shores at top', SL.nFloors, SL.nShores));
    nf = numel(SL.perFloor);
    for k = 0:nf
        plot(ax,[0 6],[-k -k],'-','Color',[0.4 0.4 0.4],'LineWidth',2);
    end
    for k = 1:nf
        ns = min(SL.perFloor(k),12);
        xs = linspace(0.5,5.5,ns);
        for x0 = xs, plot(ax,[x0 x0],[-k+1 -k],'-','Color',[0.2 0.5 0.9]); end
        text(ax,6.2,-k+0.5,sprintf('%s: %d pcs',ifelse(k==1,'n',sprintf('n-%d',k-1)),SL.perFloor(k)),'FontSize',8);
    end
    arrow(ax,[3 1.6],[3 0.05],[0 0.45 0],0.3);
    text(ax,3.2,1.2,sprintf('Pu = %.0f kN',R.Pu),'Color',[0 0.45 0],'FontSize',9);
    xlim(ax,[-0.5 8.5]); ylim(ax,[-nf-0.5 2]); set(ax,'XTick',[]); ylabel(ax,'floor below crane');

    ax = axs(3); prepAx(ax, 'Shores required per floor');
    bar(ax,0:nf-1,SL.perFloor,'FaceColor',[0.2 0.5 0.9]);
    xlabel(ax,'floor n - k'); ylabel(ax,'pcs');
end


% =====================================================================
%  LOCAL FUNCTIONS (drawing utilities)
% =====================================================================
function prepAx(ax, ttl)
    cla(ax, 'reset'); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
    title(ax, ttl, 'FontSize', 10, 'Interpreter', 'none');
end

function arrow(ax, p0, p1, col, hs)
%ARROW  Line with filled head, in data units (use with axis equal).
    d = p1 - p0;  L = norm(d);
    if L < eps, return; end
    u = d / L;  nrm = [-u(2) u(1)];  hs = min(hs, 0.6*L);
    base = p1 - hs*u;
    plot(ax, [p0(1) base(1)], [p0(2) base(2)], '-', 'Color', col, 'LineWidth', 2);
    P = [p1; base + 0.45*hs*nrm; base - 0.45*hs*nrm];
    patch(ax, P(:,1), P(:,2), col, 'EdgeColor', col);
end

function tf = isNumField(h)
    tf = isa(h, 'matlab.ui.control.NumericEditField');
end

function s = onoff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end

function out = ifelse(c, a, b)
    if c, out = a; else, out = b; end
end
