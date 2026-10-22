function out = helper_nested_undeclared_blockvar()
% HELPER_NESTED_UNDECLARED_BLOCKVAR  Used by run_tests. Static workspace
% (contains a nested function). The loop variables are declared but the
% block's variable tot is not, so the block should fail with the hint.
i = [];
j = [];
c.before = {'tot = 0;', 'tot = tot + i*j;'};
matlab_variable_depth_nested_for_loop({'i','j'}, [1 1], [1 6], 1, c);
out = getZero();
    function r = getZero()
        r = 0;
    end
end
