function nFail = run_tests()
% RUN_TESTS  Test suite for matlab_variable_depth_nested_for_loop.
%
%   nFail = run_tests()
%
%   Runs every test, prints PASS/FAIL for each, and returns the number of
%   failures. Run from anywhere; the folder holding the function (one level
%   up from this file) is added to the path automatically. Works in MATLAB
%   and in GNU Octave; the string-array test runs only in MATLAB.
%
%   Many tests compare the function's printed output, line for line,
%   against the same loops written out by hand (the hand_* subfunctions).
%
%   The helper files in this folder are callers with special workspaces:
%     helper_script_caller.m             - a script, for the caller name in warnings
%     helper_nested_ok.m                 - function with a nested function,
%                                          variables declared beforehand
%     helper_nested_undeclared_loopvar.m - same, loop variables not declared
%     helper_nested_undeclared_blockvar.m - same, a block's variable not declared
%
%   Not tested automatically: the warning text when called from the
%   command line. Try  matlab_variable_depth_nested_for_loop({'w'}, 3, 1, 1)
%   at the prompt; it should begin "Called from the command line".

testDir = fileparts(mfilename('fullpath'));
addpath(fileparts(testDir));
addpath(testDir);
check('reset');

% ---------- 1. User's i,j,k example vs hand-written loops ----------
cmds.before = cell(1, 3);
cmds.before{1} = {'disp(i)', 'disp(j)', 'disp(k)', 's2 = i^2 + j^2 + k^2;', 'disp(s2)'};
cmds.before{2} = {'disp(i+j)', 'disp(j+k)', 'disp(k+i)', 's3 = i^3 + j^3 + k^3;', 'disp(s3)'};
cmds.before{3} = {'s1 = i + j + k;', 'disp(s1)'};
got = evalc('matlab_variable_depth_nested_for_loop({''i'',''j'',''k''}, [1 1 1], [5 6 7], 1, cmds)');
want = evalc('hand_ijk()');
check('1  user i,j,k example matches hand-written loops', strcmp(got, want));
nLines = numel(strfind(got, sprintf('\n')));
check('1b line count = 5*4 + 5*6*4 + 5*6*7', nLines == 5*4 + 5*6*4 + 5*6*7, sprintf('got %d lines', nLines));

% ---------- 2. before + after blocks, accumulation, descending, fractional ----------
c2.before = {{'rowSum = 0;'}, {}, {'total = total + a*b;', 'rowSum = rowSum + b;'}};
c2.after = {{'fprintf(''a=%g rowSum=%g\n'', a, rowSum)'}, {'fprintf(''  b-loop done a=%g b=%g\n'', a, b)'}, {}};
c2.before{2} = 'nB = nB + 1;';
total = 0;
nB = 0;
got = evalc('matlab_variable_depth_nested_for_loop({''a'',''b'',''c''}, [3 0 1], [1 1 2], [1 0.25 1], c2, ''quiet'')');
total_auto = total;
nB_auto = nB;
total = 0;
nB = 0;
want = evalc('hand_abc()');
[total_hand, nB_hand] = hand_abc_totals();
check('2  before/after blocks match hand-written loops', strcmp(got, want));
check('2b variables persist in calling function workspace', abs(total_auto - total_hand) < 1e-12 && nB_auto == nB_hand, ...
    sprintf('auto total=%g nB=%g, hand total=%g nB=%g', total_auto, nB_auto, total_hand, nB_hand));
check('2c loop variables left at last values in caller', a == 1 && b == 1 && c == 2, sprintf('a=%g b=%g c=%g', a, b, c));

% ---------- 3. Warning on flipped sign, names this function ----------
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''p'',''q''}, [5 0], [1 2], [1 -1])');
[msg, id] = lastwarn();
check('3  warning issued with correct id', strcmp(id, 'matlab_variable_depth_nested_for_loop:stepSignFlipped'), id);
check('3b warning starts with calling function', ~isempty(regexp(msg, '^Called from run_tests', 'once')), msg);
check('3c warning lists both flipped variables', ~isempty(strfind(msg, 'p: 5 to 1, step used = -1')) && ~isempty(strfind(msg, 'q: 0 to 2, step used = 1')), msg);
check('3d warning ends with quiet syntax', ~isempty(regexp(msg, 'loop_commands, ''quiet''\)$', 'once')), msg);
fprintf('\n----- full warning text -----\n%s\n-----------------------------\n\n', msg);

% ---------- 4. quiet suppresses it; logical true too; correct values anyway ----------
lastwarn('');
got = evalc('matlab_variable_depth_nested_for_loop({''p''}, 5, 1, 2, ''quiet'')');
check('4  quiet: no warning', isempty(lastwarn()));
check('4b descending 5:-2:1 values', strcmp(got, sprintf('p = 5   \np = 3   \np = 1   \n')), got);
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''p''}, 5, 1, 2, true)');
check('4c logical true also quiet', isempty(lastwarn()));
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''p''}, 5, 1, -2)');
check('4d correct sign given: no warning', isempty(lastwarn()));

% ---------- 5. Function handle mode ----------
got = evalc('matlab_variable_depth_nested_for_loop({''x'',''y''}, [1 1], [3 4], 1, @(v) fprintf(''%d\n'', v.x*v.y))');
want = '';
for x = 1:3
    for y = 1:4
        want = [want sprintf('%d\n', x*y)];
    end
end
check('5  function handle mode', strcmp(got, want));

% ---------- 6. Point counts match colon operator, incl. awkward float steps ----------
cases = {0, 1, 0.1; 1, 0, 0.1; 0, 0.3, 0.1; 0, 1, 0.3; 0.1, 0.7, 0.2; 2, -1, 0.5; 0, 0, 1; 1e-3, 2e-3, 1e-4; 0, 10, 3; 300, 100, 50};
allOk = true;
bad = '';
for r = 1:size(cases, 1)
    lo = cases{r, 1};
    hi = cases{r, 2};
    st = abs(cases{r, 3}) * sign(hi - lo + (hi == lo));
    ref = lo:st:hi;
    collected = collect_values(lo, hi, st);
    if numel(collected) ~= numel(ref) || max(abs(collected - ref)) > 1e-12
        allOk = false;
        bad = [bad sprintf('[%g %g %g: %d vs %d] ', lo, hi, st, numel(collected), numel(ref))];
    end
end
check('6  point count and values match lo:step:hi in 10 cases', allOk, bad);

% ---------- 7. Scalar step, single level, equal limits ----------
got = evalc('matlab_variable_depth_nested_for_loop({''m'',''n''}, [1 1], [2 2], 1)');
check('7  scalar step expands to all levels', strcmp(got, sprintf('m = 1   n = 1   \nm = 1   n = 2   \nm = 2   n = 1   \nm = 2   n = 2   \n')), got);
lastwarn('');
got = evalc('matlab_variable_depth_nested_for_loop({''m''}, 4, 4, -3)');
check('7b equal limits: one pass, no warning', strcmp(got, sprintf('m = 4   \n')) && isempty(lastwarn()), got);

% ---------- 8. Multi-line control flow split across cell elements ----------
c8.before = {{}, {'if mod(v, 2) == 0', '    fprintf(''even %d\n'', v)', 'else', '    fprintf(''odd %d\n'', v)', 'end'}};
got = evalc('matlab_variable_depth_nested_for_loop({''u'',''v''}, [1 1], [1 3], 1, c8)');
check('8  if/else block spanning several cell elements', strcmp(got, sprintf('odd 1\neven 2\nodd 3\n')), got);

% ---------- 9. Fewer entries than levels; only after field ----------
c9.after = {'fprintf(''done g=%d\n'', g)'};
got = evalc('matlab_variable_depth_nested_for_loop({''g'',''h''}, [1 1], [2 3], 1, c9)');
check('9  only after{1} given, inner levels empty', strcmp(got, sprintf('done g=1\ndone g=2\n')), got);

% ---------- 10. Inner variables read at outer level ----------
c10.before = {'fprintf(''outer sees h=%d\n'', h)'};
c10.after = {'fprintf(''after sees h=%d\n'', h)'};
got = evalc('matlab_variable_depth_nested_for_loop({''g'',''h''}, [1 5], [2 1], [1 2], c10, ''quiet'')');
check('10 before sees inner start value, after sees last value', ...
    strcmp(got, sprintf('outer sees h=5\nafter sees h=1\nouter sees h=5\nafter sees h=1\n')), got);

% ---------- 11. Errors ----------
check('11a zero step', throws_id('matlab_variable_depth_nested_for_loop({''a''}, 1, 2, 0)', 'zeroStep'));
check('11b size mismatch', throws_id('matlab_variable_depth_nested_for_loop({''a'',''b''}, [1 1], 2, 1)', 'sizeMismatch'));
check('11c bad variable name', throws_id('matlab_variable_depth_nested_for_loop({''2x''}, 1, 2, 1)', 'badName'));
check('11d non-finite limit', throws_id('matlab_variable_depth_nested_for_loop({''a''}, 1, Inf, 1)', 'nonFinite'));
check('11e misspelled struct field', throws_id('matlab_variable_depth_nested_for_loop({''a''}, 1, 2, 1, struct(''befor'', {{''disp(a)''}}))', 'badCommands'));
check('11f too many entries', throws_id('matlab_variable_depth_nested_for_loop({''a''}, 1, 2, 1, struct(''before'', {{''x=1;'', ''y=2;''}}))', 'badCommands'));
check('11g bad optional input', throws_id('matlab_variable_depth_nested_for_loop({''a''}, 1, 2, 1, 7)', 'badOption'));
try
    matlab_variable_depth_nested_for_loop({'a','b'}, [1 1], [2 2], 1, struct('before', {{'', 'q = undefinedThing + 1;'}}));
    check('11h error inside block reported with location', false, 'no error thrown');
catch ME
    ok = strcmp(ME.identifier, 'matlab_variable_depth_nested_for_loop:blockError') && ~isempty(strfind(ME.message, 'loop_commands.before{2} (loop over b), with a = 1  b = 1')) && ~isempty(strfind(ME.message, 'undefinedThing'));
    check('11h error inside block reported with location', ok, ME.message);
end

% ---------- 12. Internal names can't be clobbered by user code ----------
c12.before = {{}, {'count = 99;', 'level = 0;', 'done = true;', 'nIter = 1;'}};
got = evalc('matlab_variable_depth_nested_for_loop({''count'',''level''}, [1 1], [2 2], 1, c12)');
check('12 user code using internal names does not break loop', isempty(got) && count == 99, got);
c12b.before = {{}, {'hits = hits + 1;', 'count = 99;'}};
hits = 0;
evalc('matlab_variable_depth_nested_for_loop({''aa'',''bb''}, [1 1], [3 4], 1, c12b)');
check('12b loop still runs every pass when user sets internal names', hits == 12, sprintf('hits=%d', hits));

% ---------- 13. Called from the command line / base workspace ----------
evalin('base', 'clear zz_total');
evalin('base', 'zz_total = 0;');
evalin('base', 'matlab_variable_depth_nested_for_loop({''zi'',''zj''}, [1 1], [3 2], 1, struct(''before'', {{'''', ''zz_total = zz_total + zi*zj;''}}))');
check('13 runs in base workspace when called from command line', evalin('base', 'zz_total') == 18);
evalin('base', 'clear zz_total zi zj');

% ---------- 14. Caller with nested functions (static workspace) ----------
try
    evalc('helper_nested_undeclared_loopvar();');
    if exist('OCTAVE_VERSION', 'builtin') ~= 0
        fprintf('SKIP  14  Octave allows assignin into a static workspace, MATLAB does not\n');
    else
        check('14  undeclared loop variable in static workspace gives hint', false, 'no error thrown');
    end
catch ME
    ok = strcmp(ME.identifier, 'matlab_variable_depth_nested_for_loop:staticWorkspace') && ~isempty(strfind(ME.message, 'initial value'));
    check('14  undeclared loop variable in static workspace gives hint', ok, ME.message);
end
check('14b static workspace with declared variables works', helper_nested_ok() == 21);
try
    helper_nested_undeclared_blockvar();
    check('14c undeclared block variable in static workspace gives hint', false, 'no error thrown');
catch ME
    ok = strcmp(ME.identifier, 'matlab_variable_depth_nested_for_loop:blockError') && ~isempty(strfind(ME.message, 'loop_commands.before{1}')) && ~isempty(strfind(ME.message, 'initial value'));
    check('14c undeclared block variable in static workspace gives hint', ok, ME.message);
    fprintf('\n----- static workspace message -----\n%s\n------------------------------------\n\n', ME.message);
end

% ---------- 15. Warning names a calling script ----------
lastwarn('');
evalc('helper_script_caller');
check('15 warning names the calling script', ~isempty(regexp(lastwarn(), '^Called from helper_script_caller', 'once')), lastwarn());

% ---------- 16. MATLAB string arrays for names and code (MATLAB only) ----------
if exist('OCTAVE_VERSION', 'builtin') ~= 0
    fprintf('SKIP  16 string arrays (Octave has no string class)\n');
else
    c16.before = {'', string({'s = x + y;', 'fprintf(''%d\n'', s)'})};
    c16.after = {string('fprintf(''row %d\n'', x)')};
    got = evalc('matlab_variable_depth_nested_for_loop(string({''x'',''y''}), [1 1], [2 2], 1, c16)');
    check('16 string array names, string array block, scalar string block', strcmp(got, sprintf('2\n3\nrow 1\n3\n4\nrow 2\n')), got);
    lastwarn('');
    evalc('matlab_variable_depth_nested_for_loop({''x''}, 1, 2, 1, string(''quiet''))');
    evalc('matlab_variable_depth_nested_for_loop({''x''}, 2, 1, 1, string(''quiet''))');
    check('16b quiet given as a string', isempty(lastwarn()));
end

% ---------- 17. Same code in innermost before and after ----------
c17.before = {'', {'s = u + v;', 'n17 = n17 + 1;'}};
c17.after = {'', {' s = u + v ', '% just a comment', '', 'n17 = n17 + 1'}};
n17 = 0;
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''u'',''v''}, [1 1], [2 3], 1, c17)');
[msg, id] = lastwarn();
check('17  duplicate innermost block detected despite spacing/semicolons/comments', strcmp(id, 'matlab_variable_depth_nested_for_loop:duplicateInnermostBlock'), id);
check('17b duplicate warning names caller, blocks and loop', ~isempty(regexp(msg, '^Called from run_tests', 'once')) && ~isempty(strfind(msg, 'before{2} and loop_commands.after{2}')) && ~isempty(strfind(msg, 'loop (over v)')), msg);
check('17c duplicate warning asks for confirmation and gives off switch', ~isempty(strfind(msg, 'Please confirm')) && ~isempty(strfind(msg, 'duplicateInnermostBlock'')')), msg);
check('17d code still runs twice per pass as written', n17 == 12, sprintf('n17=%d', n17));
fprintf('\n----- duplicate block warning -----\n%s\n-----------------------------------\n\n', msg);
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''u'',''v''}, [1 1], [2 3], 1, struct(''before'', {{'''', ''x1 = 1;''}}, ''after'', {{'''', ''x2 = 2;''}}))');
check('17e different innermost blocks: no warning', isempty(lastwarn()), lastwarn());
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''u'',''v''}, [1 1], [2 3], 1, struct(''before'', {{''y1 = 1;'', ''''}}, ''after'', {{''y1 = 1;'', ''''}}))');
check('17f same code at an outer level (not back to back): no warning', isempty(lastwarn()), lastwarn());
lastwarn('');
n17 = 0;
evalc('matlab_variable_depth_nested_for_loop({''u''}, 1, 3, 1, struct(''before'', {{''m17 = u;''}}, ''after'', {{''n17 = n17 + 1;''}}))');
check('17g single level with different before/after: no warning', isempty(lastwarn()) && n17 == 3, lastwarn());

% ---------- 18. Struct with no code anywhere ----------
defaultOut = evalc('matlab_variable_depth_nested_for_loop({''i'',''j''}, [1 1], [2 3], 1)');
c18.before = {'', {}};
c18.after = {'   ', {'% only a comment', ''}};
lastwarn('');
got = evalc('matlab_variable_depth_nested_for_loop({''i'',''j''}, [1 1], [2 3], 1, c18)');
[msg, id] = lastwarn();
check('18  all-empty blocks give noCodeToRun warning', strcmp(id, 'matlab_variable_depth_nested_for_loop:noCodeToRun'), id);
check('18b no-code warning names caller and explains default with line count', ~isempty(regexp(msg, '^Called from run_tests', 'once')) && ~isempty(strfind(msg, 'values of i, j will be printed')) && ~isempty(strfind(msg, '(6 lines)')), msg);
gotLines = regexp(got, '[ij] = .*', 'match', 'dotexceptnewline');
wantLines = regexp(defaultOut, '[ij] = .*', 'match', 'dotexceptnewline');
check('18c falls back to printing the index values', isequal(gotLines, wantLines) && numel(wantLines) == 6, got);
fprintf('\n----- no-code warning -----\n%s\n---------------------------\n\n', msg);
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''i''}, 1, 2, 1, struct())');
check('18d struct with no fields also warns', ~isempty(strfind(lastwarn(), 'every before and after block')), lastwarn());
lastwarn('');
evalc('matlab_variable_depth_nested_for_loop({''i''}, 1, 2, 1)');
check('18e loop_commands omitted: default printing without a warning', isempty(lastwarn()), lastwarn());

nFail = check('report');
end


function vals = collect_values(lo, hi, st)
vals = [];
c.before = {'vals(end+1) = t;'};
matlab_variable_depth_nested_for_loop({'t'}, lo, hi, st, c, 'quiet');
end


function ok = throws_id(cmd, idTail)
ok = false;
try
    evalin('caller', cmd);
catch ME
    ok = strcmp(ME.identifier, ['matlab_variable_depth_nested_for_loop:' idTail]);
end
end


function hand_ijk()
for i = 1:5
    disp(i)
    % The function gives inner variables their start values before an
    % outer block runs, so j and k are 1 here on every pass of i
    j = 1;
    k = 1;
    disp(j)
    disp(k)
    s2 = i^2 + j^2 + k^2;
    disp(s2)
    for j = 1:6
        k = 1;
        disp(i+j)
        disp(j+k)
        disp(k+i)
        s3 = i^3 + j^3 + k^3;
        disp(s3)
        for k = 1:7
            s1 = i + j + k;
            disp(s1)
        end
    end
end
end


function hand_abc()
total = 0;
nB = 0;
for a = 3:-1:1
    rowSum = 0;
    for b = 0:0.25:1
        nB = nB + 1;
        for c = 1:2
            total = total + a*b;
            rowSum = rowSum + b;
        end
        fprintf('  b-loop done a=%g b=%g\n', a, b)
    end
    fprintf('a=%g rowSum=%g\n', a, rowSum)
end
end


function [total, nB] = hand_abc_totals()
total = 0;
nB = 0;
for a = 3:-1:1
    for b = 0:0.25:1
        nB = nB + 1;
        for c = 1:2
            total = total + a*b;
        end
    end
end
end


function nFailOut = check(name, ok, detail)
% CHECK  Record and print one test result. check('reset') clears the
% tally; check('report') prints it and returns the number of failures.
persistent nPass nFail
nFailOut = [];
if strcmp(name, 'reset')
    nPass = 0;
    nFail = 0;
    return
end
if strcmp(name, 'report')
    fprintf('\n%d passed, %d failed\n', nPass, nFail);
    nFailOut = nFail;
    return
end
if ok
    nPass = nPass + 1;
    fprintf('PASS  %s\n', name);
else
    nFail = nFail + 1;
    fprintf('FAIL  %s\n', name);
    if nargin > 2
        fprintf('      %s\n', detail);
    end
end
end
