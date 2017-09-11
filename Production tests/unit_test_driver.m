function [  ] = unit_test_driver( )
%UNIT_TEST_DRIVER Driver function for BEHR unit test
%   This function, when called, asks a series of questions interactively to
%   determine how the unit tests should proceed. It is capable of
%   automatically generating OMI_SP and OMI_BEHR files using the current
%   versions of read_omno2_v_aug2012 and BEHR_main, if this is requested,
%   it saves the resulting files in a subdirectory of "UnitTestData" which
%   will be created in the same directory as this function. The
%   subdirectory will be named "ProducedYYYYMMDD". It will also contain a
%   text file that describes the status of the BEHR git repository at the
%   time of production, including both the commit hash and one line
%   description of HEAD and the diff against HEAD.
%
%   Whether you produce the data with this function or not, it will then
%   called both BEHR_UNIT_TEST and (if testing read_omno2_v_aug2012)
%   READING_PRIORI_TESTS. BEHR_UNIT_TEST takes a pair of Data or OMI
%   structures and attempts to verify that they are the same. If they are
%   not the same, the unit test will fail overall for that date, but will
%   also print out information about why it failed. Since changes to the
%   algorithm intended to change the output will cause it to fail, it is up
%   to the user to determine if the changes are the expected ones.
%   READING_PRIORI_TESTS does not test the a priori profiles; rather it
%   checks that certain elements of the OMI_SP files make sense a priori,
%   that is, on their own without needing a previous version of the file to
%   compare against.
%
%   At a minimum, this should be used before producing a new version of
%   BEHR to test selected dates (see below) against the existing version.
%   This would be done by allowing it to generate the new data and compare
%   against the files in the directories specified by BEHR_paths().
%
%   This does not run the entire OMI data record. Within the code is a cell
%   array of test dates which will be run. A few days are included in this
%   array to test normal operation, the rest are there to test behavior
%   under weird cases that have caused issues in the past. Consequently,
%   you should add days to this as you find days that cause the BEHR
%   algorithm to error or behave strangely, but you should not remove
%   existing days.
%
%   Josh Laughner <joshlaugh5@gmail.com> 8 May 2017

E = JLLErrors;
DEBUG_LEVEL = 2;

% Test these dates. It's a good idea to check at least one regular day
% before the row anomaly started (2005-2006), after it was at its worst
% (after July 2011), plus zoom mode operation in both time periods.
% Additional days should be added that have caused or illuminated bugs

test_region = 'US';

test_dates = {'2005-06-02';... % pre-row anomaly summertime day, at least one day after zoom mode finishes
              '2006-01-01';... % pre-row anomaly wintertime day, at least one day after zoom mode finishes
              '2012-06-03';... % post-row anomaly summertime day, at least one day after zoom mode finishes
              '2013-01-01';... % post-row anomaly wintertime day, at least one day after zoom mode finishes
              '2014-07-08';... % post-row anomaly zoom mode, found by looking for days where OMPIXCORZ is produced for BEHR-relevant orbits for US region
              '2006-09-20';... % pre-row anomaly zoom mode, found by looking for days where OMPIXCORZ is produced for BEHR-relevant orbits for US region
              '2005-07-13';... % day mentioned in the 2.1Arev1 changelog with no NO2 data
              '2010-01-29';... % day mentioned in the 2.1Arev1 changelog with no NO2 data
              '2005-05-04';... % the center lon/lat for the OMPIXCOR product just different enough that cutting down by bounds results in different size arrays, so switched to find_submatrix2
              '2005-05-14'... % Has both a row that is only partially fill values in lon/lat and the OMPIXCOR corners are mostly 0
              };

% These are dates that the algorithm should be run for, but for which it is
% okay if no data is produced. This allows the unit tests to skip them
test_dates_no_data = {'2016-05-30'};  % OMI was in safe mode; algorithm should gracefully handle the lack of data
              

test_dates = unique(cat(1,test_dates,test_dates_no_data));
my_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(my_dir,'SubTests'));
what_to_test = ask_multichoice('Which step should be tested?', {'all', 'reading', 'behrmain'});

use_behrpaths = ask_yn('Use the paths specified by BEHR_paths() for the old data?');
generate_new_data = ask_yn('Generate the new files? If not you will be asked to choose the directories to load new files from');
if generate_new_data
    save_folder = make_data_folder();
end

save_results_to_file = ask_yn('Save results to file? (If not, will be printed to screen).');
if save_results_to_file
    results_file = make_results_file(what_to_test);
    fid = fopen(results_file,'w');
else 
    % An fid of 1 will cause fprintf to print to the command window, as if
    % no fid was given
    fid = 1;
end

fields_to_ignore = input('Specify any fields to ignore in unit testing, separated by a space: ', 's');
fields_to_ignore = strsplit(fields_to_ignore);

if generate_new_data
    make_git_report();
end
switch what_to_test
    case 'reading'
        success = test_reading();
    case 'behrmain'
        success = test_behr_main();
    case 'all'
        success = test_all();
    otherwise
        E.notimplemented(what_to_test);
end
    
for a=1:numel(success)
    fprintf(fid, '%s: %s\n', datestr(test_dates{a}), passfail(success(a)));
end
fprintf(fid, 'Overall: %s\n', passfail(all(success)));

msg = sprintf('BEHR unit test completed on %s step(s): %s', what_to_test, datestr(now));
border = repmat('*', 1, numel(msg));
fprintf(fid, '\n%s\n', border);
fprintf(fid, '%s\n', msg);
fprintf(fid, '%s\n\n', border);
if fid > 2
    fclose(fid);
end

if save_results_to_file
    fprintf('Results saved to %s\n', results_file);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% NESTED FUNCTIONS %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function dfolder = make_data_folder()
        dfolder = fullfile(my_dir, 'UnitTestData', sprintf('Produced%s', datestr(today, 'yyyymmdd')));
        if exist(dfolder, 'dir')
            if ~ask_yn(sprintf('Directory\n %s\n exists, it will be cleared before continuing. Proceed?', dfolder))
                E.userCancel()
            else
                delete(fullfile(dfolder, '*'));
            end
        else
            mkdir(dfolder);
        end
        fprintf('Unit test data will be stored in %s\n', dfolder);
    end

    function rfile = make_results_file(test_steps)
        rfolder = fullfile(my_dir, 'UnitTestResults');
        if ~exist(rfolder, 'dir')
            mkdir(rfolder);
        end
       rfilename = sprintf('BEHR_%s_Unit_Test_Results_%s.txt', test_steps, datestr(now, 'yyyymmdd_HHMMSS'));
       rfile = fullfile(rfolder, rfilename);
    end

    function make_git_report()
        currdir = cd(behr_repo_dir());
        % Overall status (current branch, modified/added/deleted/untracked
        % files). Use --porcelain to remove formatting (bold, color, etc)
        % and --branch to force it to show the branch. --no-pager means it
        % won't try to put the output through "less" and avoids a "terminal
        % not fully functional" warning.
        [~, gitstat] = system('git --no-pager status --porcelain --branch');
        
        % Get the one line commit message for the last, decorated with any
        % tags or branch heads. Remove color to avoid introducing special
        % characters into the text.
        [~, githead] = system('git --no-pager log -1 --pretty=oneline --decorate --no-color');
        
        % Get the differenced since the last commit, sans color and pager
        % for the same reasons as above. By specifically diffing against
        % HEAD, we get staged and unstaged changes.
        [~, gitdiff] = system('git --no-pager diff --no-color HEAD');
        cd(currdir);
        
        % Extract the branch from the status - with "--porcelain --branch"
        % it is on its own line prefaced by ##
        [i,j] = regexp(gitstat, '##.*?\n', 'once');
        gitbranch = gitstat(i:j);
        gitbranch = strrep(gitbranch, '#', '');
        gitbranch = strtrim(gitbranch);
        gitstat(i:j) = [];
        
        % Also add space before each file in the diff (usually the "diff
        % --git" is bolded so it's easier to see but we removed formatting)
        gitdiff = strrep(gitdiff, 'diff --git', sprintf('\ndiff --git'));
        
        gfid = fopen(fullfile(save_folder, 'GitReport.txt'), 'w');
        begin_msg = sprintf('Git report for unit test data generated on %s', datestr(now));
        gborder = repmat('*', size(begin_msg));
        
        fprintf(gfid, '%s\n%s\n%s\n\n', gborder, begin_msg, gborder); 
        fprintf(gfid, 'Current branch: %s\n\n', gitbranch);
        fprintf(gfid, 'HEAD at time of generation:\n%s\n%s\n\n', githead, gborder);
        fprintf(gfid, 'Git status at time of generation\n  (M = modified, A = added, D = deleted, ?? = untracked):\n\n%s\n%s\n\n', gitstat, gborder);
        fprintf(gfid, 'Git diff (working dir against HEAD) at time of generation:\n\n%s', gitdiff);
        fclose(gfid);
    end

    function successes = test_all()
        read_success = test_reading();
        behr_success = test_behr_main(save_folder);
        successes = read_success & behr_success;
    end

    function successes = test_reading()
        if generate_new_data
            new_dir = save_folder;
            for i=1:numel(test_dates)
                read_omno2_v_aug2012('start', test_dates{i}, 'end', test_dates{i}, 'sp_mat_dir', save_folder, 'overwrite', true, 'region', test_region);
            end
        else
            fprintf('You''ll need to choose the directory with the new OMI_SP files for the following dates:\n  %s\n (press ENTER)\n', strjoin(test_dates, ', '));
            input('','s'); % wait for the user
            new_dir = getdir;
            if ~exist('save_folder', 'var')
                save_folder = new_dir;
            end
        end
        
        if use_behrpaths
            old_dir = BEHR_paths('sp_mat_dir');
        else
            fprintf('You''ll need to choose the directory with the old OMI_SP files for the following dates:\n  %s\n (press ENTER)\n', strjoin(test_dates, ', '));
            input('', 's'); % wait for the user
            old_dir = getdir;
        end
        
        successes = true(size(test_dates));
        for i=1:numel(test_dates)
            if DEBUG_LEVEL > 0
                fprintf(fid, '\n');
            end
            filepat = sp_savename(test_dates{i}, '.mat', true);
            try
                [old_data, old_file] = load_by_glob(fullfile(old_dir, filepat));
                [new_data, new_file] = load_by_glob(fullfile(new_dir, filepat));
            catch err
                if strcmp(err.identifier, 'load_by_glob:file_not_found')
                    if ismember(test_dates{i}, test_dates_no_data)
                        if DEBUG_LEVEL > 0
                            fprintf(fid, 'No data for %s as expected\n', test_dates{i});
                        end
                    else
                        if DEBUG_LEVEL > 0
                            fprintf(fid, 'FAIL: No data produced for %s!!!\n', test_dates{i});
                        end
                    end
                    continue
                else
                    rethrow(err);
                end
            end
            if DEBUG_LEVEL > 0
                fprintf(fid, '\nChecking %s\n', test_dates{i});
                fprintf(fid, 'Loaded old file: %s\n', old_file{1});
                fprintf(fid, 'Loaded new file: %s\n', new_file{1});
            end
            
            if DEBUG_LEVEL > 0
                header_msg = '***** Running priori tests on data read in ****';
                header_border = repmat('*', 1, length(header_msg));
                fprintf(fid, '\n%1$s\n%2$s\n%1$s\n', header_border, header_msg);
            end
            
            successes(i) = reading_priori_tests(new_data.Data, DEBUG_LEVEL, fid) && successes(i);
            
            if DEBUG_LEVEL > 0
                header_msg = '***** Running reading unit tests, comparing to previous data ****';
                header_border = repmat('*', 1, length(header_msg));
                fprintf(fid, '\n%1$s\n%2$s\n%1$s\n', header_border, header_msg);
            end
            
            successes(i) = behr_unit_test(new_data.Data, old_data.Data, DEBUG_LEVEL, fid, fields_to_ignore) && successes(i);
        end
    end

    function successes = test_behr_main(sp_data_dir)
        if generate_new_data
            new_dir = save_folder;
            if ~exist('sp_data_dir', 'var')
                if ask_yn('Use the paths specified by BEHR_paths() for the SP files to be read into BEHR_main?');
                    sp_data_dir = BEHR_paths('sp_mat_dir');
                else
                    fprintf('You''ll need to choose the directory with existing OMI_SP files for the following dates:\n  %s\n (press ENTER)\n', strjoin(test_dates, ', '));
                    input('','s'); %wait for the user
                    sp_data_dir = getdir;
                end
            end
            
            for i=1:numel(test_dates)
                BEHR_main('start', test_dates{i}, 'end', test_dates{i}, 'behr_mat_dir', save_folder, 'sp_mat_dir', sp_data_dir, 'overwrite', true);
            end
        else
            if ~exist('sp_data_dir', 'var')
                fprintf('You''ll need to choose the directory with the new OMI_BEHR files for the following dates:\n  %s\n (press ENTER)\n', strjoin(test_dates, ', '));
                input('','s'); %wait for the user
                new_dir = getdir;
            else
                new_dir = sp_data_dir;
            end
        end
        
        if use_behrpaths
            old_dir = BEHR_paths('behr_mat_dir');
        else
            fprintf('You''ll need to choose the directory with the old OMI_BEHR files for the following dates (press ENTER)\n');
            input('','s'); % wait for the user
            old_dir = getdir;
        end
        
        successes_data = false(size(test_dates));
        successes_grid = false(size(test_dates));
        for i=1:numel(test_dates)
            if DEBUG_LEVEL > 0
                fprintf(fid, '\n');
            end
            filepat = behr_filename(test_dates{i}, '.mat', true);
            try
                [old_data, old_file] = load_by_glob(fullfile(old_dir, filepat));
                [new_data, new_file] = load_by_glob(fullfile(new_dir, filepat));
            catch err
                if strcmp(err.identifier, 'load_by_glob:file_not_found')
                    if ismember(test_dates{i}, test_dates_no_data)
                        if DEBUG_LEVEL > 0
                            fprintf(fid, 'No data for %s as expected\n', test_dates{i});
                        end
                        successes_data(i) = true;
                        successes_grid(i) = true;
                    else
                        if DEBUG_LEVEL > 0
                            fprintf(fid, 'FAIL: No data produced for %s!!!\n', test_dates{i});
                        end
                    end
                    continue
                else
                    rethrow(err);
                end
            end
            if DEBUG_LEVEL > 0
                fprintf(fid, '\nChecking %s\n', test_dates{i});
                fprintf(fid, 'Loaded old file: %s\n', old_file{1});
                fprintf(fid, 'Loaded new file: %s\n', new_file{1});
            end
            
            if DEBUG_LEVEL > 0
                header_msg = '***** Running BEHR_main unit tests on Data struct ****';
                header_border = repmat('*', 1, length(header_msg));
                fprintf(fid, '\n%1$s\n%2$s\n%1$s\n', header_border, header_msg);
            end
            
            successes_data(i) = behr_unit_test(new_data.Data, old_data.Data, DEBUG_LEVEL, fid, fields_to_ignore);
            
            if DEBUG_LEVEL > 0
                header_msg = '***** Running BEHR_main unit tests on OMI struct ****';
                header_border = repmat('*', 1, length(header_msg));
                fprintf(fid, '\n%1$s\n%2$s\n%1$s\n', header_border, header_msg);
            end
            
            successes_grid(i) = behr_unit_test(new_data.OMI, old_data.OMI, DEBUG_LEVEL, fid, fields_to_ignore);
        end
        
        successes = successes_data & successes_grid;
    end

end

function s = passfail(b)
if b
    s = 'PASS';
else
    s = 'FAIL';
end
end

function d = getdir()
E=JLLErrors;
if isDisplay
    d = uigetdir;
else
    while true
        d = input('Enter the directory: ', 's');
        if strcmpi(d,'q')
            E.userCancel;
        elseif exist(d, 'dir')
            break
        else
            fprintf('That directory does not exist.\n')
        end
    end
end
end
