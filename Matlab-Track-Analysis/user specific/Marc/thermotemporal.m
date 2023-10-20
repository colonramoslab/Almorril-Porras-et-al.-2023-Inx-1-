%% Set up cryophilic point labeling
% An example script with annotations
%%

existsAndDefault('fromScratch', false);
%% LOADING FILES FROM DISK
% loading specific files by name
ts1 = tic;
existsAndDefault('marcmac', false);
if (marcmac)
    basedir =  '~/Documents/lab data/n2cryo/';
else
    basedir = '\\labnas2\WormData\David\Temporal Data\N2 G 25\AllBinsTimsTmps\';
end
d = dir(fullfile(basedir, '*.bin'));
nfiles = 24;
if (fromScratch)
    nfiles = min(nfiles, length(d));
    for j = 1:nfiles
        fnames{j} = [basedir d(j).name]; %#ok<SAGROW>
    end
    %fnames = {[basedir '20090226_N2g15_1823_tracks.bin'], [basedir '20090226_w1a_N2g15_1823_tracks.bin']};

    % load any track longer than 50 points
    minpts = 50;

    % this code snippet loads the files if we haven't already loaded them, but
    % otherwise skips them; that way we can change the script and rerun it
    % without having to reload the files
    if (~exist('ttemp', 'var'))
        ttemp = ExperimentSet.fromFiles(fnames{:}, 'minpts', minpts);
    end

    %% STITCH TRACKS
    % sometimes we miss a frame, so let's stitch together tracks that are close
    % by

    frameDiff = 3; % stitch together tracks if first ended 3 or fewer frames before second started
    maxDist = 7; % stitch together tracks if first ended within 7 pixels of second's start

    % For the script, I am executing this function with interactive off, but if
    % you set interactive to true, it will show you each potential stitch and
    % let you decide whether or not to stitch it
    ttemp.executeExperimentFunction('stitchTracks', frameDiff, maxDist, 'interactive', false);

    %% CLEAN UP TRACKS
    % get rid of any tracks that don't go anywhere

    % create an EsetCleaner object

    ecl = ESetCleaner();

    % now let's look at the autogenerated report
    % let's get rid of all tracks less than 750 points and speed less than 0.4
    % pixels per second
    ecl.minPts = 750;
    ecl.minSpeed = 0.9;

    %ecl.getReport(ttemp);

    % the following code just forces the figures to appear in the example documentation
    %{
    for j = 1:3
        figure(j);
        snapnow; 
    end
    %}

    % we've already shown the report, so we don't need to have it ask us first,
    % for the purposes of this script;  generally a good idea to leave this
    % enabled
    ecl.askFirst = false; 

    ecl.clean(ttemp);
    disp('done with loading, stitching and cleaning');
    toc(ts1)
    ts1 = tic;
    addTemperatureToExperiment(ttemp.expt,'tmpchannel',8);
    
   % save (fullfile(basedir, 'marcmatfile.mat'), 'ttemp');
    mkdir (fullfile(basedir, 'matfiles'));
    ttemp.toMatFiles(fullfile(basedir, 'matfiles','thermo_temporal'));
    disp('saved file');
    toc(ts1)
    fromScratch = false;
    resegment = true;
else
    if (~exist('ttemp', 'var'))
        ts1 = tic;
        ttemp = ExperimentSet.fromMatFiles(fullfile(basedir, 'matfiles','thermo_temporal'));
        disp ('loaded eset from mat file');
        toc(ts1)
    end
end



existsAndDefault('resegment', false);
if (resegment)
    disp ('segmenting tracks');
    wso = WormSegmentOptions;
    ts1 = tic;
    ttemp.executeExperimentFunction('segmentTracks', wso);
    disp ('done segmenting');
    toc(ts1)
    resegment = false;
end

fignum = 0;
fignum = fignum + 1; figure(fignum); clf(fignum);
dtx =  -1.5E-3:5E-5:1.5E-3;
tempreorate = ttemp.makeReorientationHistogram('dtemp',dtx, 'makePlot', true);

fignum = fignum + 1; figure(fignum); clf(fignum);
dtx =  -1.5E-3:5E-5:1.5E-3;
tempreorated = ttemp.makeReorientationHistogram('dtemp',dtx, 'makePlot', true, 'vsDistance', true);


fignum = fignum + 1; figure(fignum); clf(fignum);
xdat = ttemp.gatherField('dtemp', 'runs');
ydat = abs(ttemp.gatherField('deltatheta', 'runs'));
dtmax = 0.3;
%sum(ydat > dtmax)/length(ydat)
ydat(ydat > dtmax) = dtmax;
[dtc, mdt] = meanyvsx(xdat, ydat, dtx);
plot (dtc, mdt); title ('mean abs delta theta vs. temperature change');