%VALIDATEAGAINSTEXCEL  Check derrickCraneCalc against the Excel template values.
%   Run from this folder:  validateAgainstExcel
clc;
tol = 1e-6;
fails = 0;

% ---------------- Beam sheet ----------------
in = derrickCraneDefaults('Beam');  in.useEQ = false;
R  = derrickCraneCalc(in);
ref = { 'Pd',   R.Pd,              1.9252125
        'Tu',   R.Tu,              346.875
        'Pu',   R.Pu,              711.685255
        'Mortar DCR', R.rows{2,5}, 0.033889774047619045
        'Bolt DCR',   R.rows{1,5}, 0.4637673965473891
        'Vc',   R.beam.Vc,         148.7329990284604
        'Vs',   R.beam.Vs,         221.74366258685907
        'Shear DCR',  R.rows{3,5}, 0.960499444009473
        'Mu+',  R.beam.Mpos,       189.78273466666667
        'Mu-',  R.beam.Mneg,       379.56546933333334
        'Mcap+',R.beam.McapP,      779.5675637819265
        'M+ DCR', R.rows{4,5},     0.24344616616162318
        'M- DCR', R.rows{5,5},     0.48689233232324636 };
fprintf('--- BEAM sheet ---\n');
for k = 1:size(ref,1)
    ok = abs(ref{k,2}-ref{k,3}) <= tol*max(1,abs(ref{k,3}));
    fails = fails + ~ok;
    fprintf('%-12s MATLAB = %14.6f   Excel = %14.6f   %s\n', ref{k,1}, ref{k,2}, ref{k,3}, char(ok*'OK  ' + ~ok*'FAIL'));
end

% ---------------- Slab sheet ----------------
in = derrickCraneDefaults('Slab');  in.useEQ = false;
R  = derrickCraneCalc(in);
ref = { 'Pd',   R.Pd,               2.7723059999999995
        'Tu',   R.Tu,               346.875
        'Pu',   R.Pu,               570.8267672
        'Bolt DCR',  R.rows{1,5},   0.30917826436492607
        'Slab Vcap', R.slab.Vcap,   475.94559689107325
        'Slab DCR',  R.rows{2,5},   0.7288122891898234
        'Floors',    R.slab.nFloors, 11
        'Shores',    R.slab.nShores, 31
        'Floor n-1', R.slab.perFloor(2), 28
        'Floor n-8', R.slab.perFloor(9), 7 };
fprintf('--- SLAB sheet ---\n');
for k = 1:size(ref,1)
    ok = abs(ref{k,2}-ref{k,3}) <= tol*max(1,abs(ref{k,3}));
    fails = fails + ~ok;
    fprintf('%-12s MATLAB = %14.6f   Excel = %14.6f   %s\n', ref{k,1}, ref{k,2}, ref{k,3}, char(ok*'OK  ' + ~ok*'FAIL'));
end

% ---------------- Earthquake demo ----------------
in = derrickCraneDefaults('Beam');
R  = derrickCraneCalc(in);
fprintf('\n--- With earthquake (defaults, hE = %.2f m) ---\n', in.hE);
fprintf('%s\n', R.report{:});

fprintf('\n%d check(s) failed.\n', fails);
