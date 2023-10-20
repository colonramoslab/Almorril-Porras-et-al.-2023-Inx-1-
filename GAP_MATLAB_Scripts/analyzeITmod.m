function [fPath, hRat, ITscore] = analyzeITmod(fPath, varargin)
%analyzeIT Extract IT behavior as function of gradient position
%   Detailed explanation goes here

% Outputs
% fPath, file path for analyzed data
% hRat, fraction of time spent IT for x-dimension in nBins
% ITscore, MAKE THIS PER TRACK METRIC!!

% optional inputs
%   travThresh, objects with less total travel are excluded (schmutz filter)
%   smW, smoothing window, default 50 frames
%   lThresh, length of continuity required to be an IT
%   nBins, hMax, hMin: histogram is from hMin:hMax in nBins steps


% initialize optional inputs
travThresh=200; % length of total travel to be considered as a worm...
smW=1; % window for smoothing to find speed.50
contThresh=50; % super arbitrary atm
prefix='';
trimX=100; % trim values from the edges for final calls.
trimY=100; % trim values from the edges for final calls.
hMax=900; hMin=0; % max & min of histogram bin edges
nBins=10; % number of bins for histogram

varargin=assignApplicable(varargin);
% assignApplicable seems to choke on directory assignment...?
while ~isempty(varargin)
    eval([varargin{1},'=','''',varargin{2},''';']);
    varargin(1:2)=[];
end

%% Load a trial data set.

% if inappropriate input, ask for file.
if ~exist('fPath','var')||isempty(fPath)
    [fN, dDir]=uigetfile('.mat','Please select .mat file with eset');
    fPath=fullfile(dDir,fN);
end

% trim 'experiment_1', which is required for fromMatFiles
bors=findstr(fPath,'experiment_1');
if ~isempty(bors)
    fPath=fPath(1:(bors-2)); %
end

eset=ExperimentSet.fromMatFiles(fPath); % load eset for analysis
% % Give tracks values... Only required if Track-wise analysis used.
% eset.expt(1).segmentTracks();

%% Establish saving directory
% Figures & saving
if  ~exist('saveDir','var')||isempty(saveDir)
    saveDir=fileparts(fPath);
    % create unique save directory for each.
    saveDir=fullfile(fPath,'plots');
end
if ~exist(saveDir,'dir')
    mkdir(saveDir);
end

%% Extract migration information
% Get values for travel in isothermal direction, Yiso, and...
% travel in orthothermal direction, Ytemp.
% Use plotXt function to extract & visualize data.
% Ytemp is temperature dimension
[ ~, ~, ~, ~, Ytemp] = plotXt( eset.expt,...
    'dim',1,'ylab','orthothermal','yts',{});
minX=min(min(Ytemp)); maxX=max(max(Ytemp));
set(gca, 'ylim', [minX, maxX]);
% Yiso is isothermal dimension
[ ~, ~, ~, ~, Yiso ] = plotXt( eset.expt,...
    'dim',2,'ylab','isothermal','yts',{});  
minY=min(min(Yiso)); maxY=max(max(Yiso)); % Edges of data. Useful to trim borders
% NOTE: trim borders later
set(gca, 'ylim', [minY, maxY]);

% Get rid of the immobile bits using travThresh
% travThresh=200; % make non-arbitrary and dynamic based on distrubition?
travLrs=nansum(abs(diff(Yiso)))+nansum(abs(diff(Ytemp)))>travThresh;
y=Yiso(:,travLrs);
x=Ytemp(:,travLrs);

%% Quantify IT based on Y-dimension speed component
% Assay IT by proportion of speed in Iso dimension, fracITspeed.
% find speed in each direction, but use smoothing to make more reliable
% over smoothing window of:
% smW=50;
smt1=smoothdata(y,1,'gaussian',smW);
smt2=smoothdata(x,1,'gaussian',smW);
itDiff=diff(smt1);
orthoDiff=diff(smt2);
speed=sqrt(itDiff.^2+orthoDiff.^2);
fracITspeed=abs(itDiff)./speed;


%% Simplify for figures into linear arrays without nans
% trim X&Y to match speed for plotting purposes
% turn into single vectors for ease of plotting
ySpeed=fracITspeed(:);
speed=speed(:);
xDisp=x(1:end-1,:);
xDisp=xDisp(:);
yDisp=y(1:end-1,:);
yDisp=yDisp(:);

% cut out nan values for position.
inVals=~isnan(yDisp); % can use later with other features
ySpeed=ySpeed(inVals);
speed=speed(inVals);
xDisp=xDisp(inVals);
yDisp=yDisp(inVals);

outThresh=nanmean(speed)+5*nanstd(speed);
speed(speed>outThresh)=nan; % remove a few outliers (17/53k)


% Extract fracITspeed as function of temperature position
% [ITvalues,indexArray] = indexAbyB(ySpeed,xDisp);

%% Call IT based on criteria
% 1. Simple fracITspeed threshold. % Do data give me a clear threshold?
% 2. Continuity above threshold. Maintained for XX length.
% 3. Maintain minimum speed?


% Combine speed, ySpeed, and continuity to ID IT
speedThresh=0.1;
yspeedThresh=0.9;
contThresh=50; % Could instead filter by physical length of continuity. 100

% first filter
passVals=and((speed>speedThresh),(ySpeed>yspeedThresh));

% calculate continuity of passing first filter
% forgiveness... eliminate very short failures.
giveThresh=5; % stretches of less than this many failures are stitched together
[lFail, ~] = stretchCounter(~passVals);
passVals(lFail<giveThresh)=1;
% encode continuity after stitching
[lPass, ~] = stretchCounter(passVals);
%
passVals2=and(passVals,lPass>contThresh);

% trim values from edges:
xtrim= and( (minX+trimX) <xDisp, xDisp< (maxX-trimX) );
ytrim= and( (minY+trimY) <yDisp, yDisp< (maxY-trimY) );
xytrim= and(xtrim,ytrim);

isIT=and(passVals2,xytrim);
notIT=and(~passVals2,xytrim);

% Extract IT calls as function of temperature position, ITcount
[ITcount,~] = indexAbyB(isIT,xDisp);
[notITcount,~] = indexAbyB(notIT,xDisp);
[ITscore,~] = indexAbyB(ySpeed,xDisp);


h1v=histcounts(xDisp(isIT)-minX,hMin:(hMax-hMin)/10:hMax);
h2v=histcounts(xDisp(notIT)-minX,hMin:(hMax-hMin)/10:hMax);
hRat=h1v./(h1v+h2v);
Hist=cat(1,h1v,h2v,hRat);
saveName=[prefix,'_Hist'];
save(fullfile(saveDir,saveName),'Hist');


% Create IT score as a function of track.
% first assign track number to each value.
trackNum=repmat(1:size(x,2),[size(x,1)-1,1]);
trackPos=repmat(1:size(x,1)-1,[size(x,2),1])';
% linearize
trackNum=trackNum(:);
trackPos=trackPos(:);
% remove positional nans, from above
trackNum=trackNum(inVals);
trackPos=trackPos(inVals);
% assign track values of isIT & notIT, back to a matrix... 
ITmat=nan(size(x));
notITmat=nan(size(x));
for ii=1:size(x,2)
    TOI=(trackNum==ii);
    POI=trackPos(TOI);
    ITmat(POI,ii)=isIT(TOI);
    notITmat(POI,ii)=notIT(TOI);
end

ITtrack=nansum(ITmat,1);
notITtrack=nansum(notITmat,1);
ITscore=ITtrack./(ITtrack+notITtrack);
%ITscore(isnan(ITscore))=0;
ITtrackscore=cat(1,ITtrack,notITtrack,ITscore);


%% Figures
% QC plot to make sure all is well on re-conversion
saveName=['plot_QC-ITcalls',prefix];
figure(); hold on;
ITindex=ITmat;
ITindex(isnan(ITindex))=0;
ITindex=logical(ITindex);
plot(x(ITindex),y(ITindex),'.r')
nITindex=notITmat;
nITindex(isnan(nITindex))=0;
nITindex=logical(nITindex);
plot(x(nITindex),y(nITindex),'.k')
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

saveName=['plot_yHist',prefix];
yITbins=histcounts(y(ITindex)-minY,hMin:(hMax-hMin)/20:hMax);
ynITbins=histcounts(y(nITindex)-minY,hMin:(hMax-hMin)/20:hMax);
figure(); hold on;
plot(yITbins,'-r');
plot(ynITbins,'-b');
yyaxis right
plot(yITbins./(ynITbins+yITbins),'--k');
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

saveName=['plot_xHist',prefix];
xITbins=histcounts(x(ITindex)-minX,hMin:(hMax-hMin)/20:hMax);
xnITbins=histcounts(x(nITindex)-minX,hMin:(hMax-hMin)/20:hMax);
figure(); hold on;
plot(xITbins,'--r');
plot(xnITbins,'--b');
yyaxis right
plot(xITbins./(xnITbins+yITbins),'-k');
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));


% simple histogram of IT.
saveName=['plot_ITbyX_histogram',prefix];
h1=histogram(xDisp(isIT),20);
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% binned density based on histogram of IT.
saveName=['plot_ITbyX_histogramRatio',prefix];
figure(); bar(hRat); 
set(gca,'xlim', [0,20],'ylim',[0,1])
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% Plot density of passing IT threshold
saveName=['plot_ITFractiondensity',prefix];
ITdensity=nansum(ITcount,2)./( nansum(ITcount,2)+ nansum(notITcount,2) );
figure(); plot(ITdensity);
hold on;
sITdensity=smoothdata(ITdensity,100);
plot(sITdensity)
set(gca,'xlim',[minX,maxX],'ylim',[0,1])
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% Plot density of IT score
saveName=['plot_ITscoredensity',prefix];
figure(); plot(nanmean(ITscore,2));
title('IT score mean')
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% X&Y with IT score as color
saveName=['plot_XbyY_ITscore',prefix];
figure(); scatter(xDisp, yDisp,10,ySpeed,'filled')
set(gca,'xlim',[minX,maxX],'ylim',[minY,maxY]);
colormap(jet)
c=colorbar;
c.Label.String='Fractional speed in IT direction';
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% X&Y with speed as color
saveName=['plot_XbyY_speed',prefix];
figure(); scatter(xDisp, yDisp,10,speed,'filled')
set(gca,'xlim',[minX,maxX],'ylim',[minY,maxY]);
colormap(jet)
c=colorbar;
c.Label.String='Speed';
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% X&Y with duration of IT passing threshold
saveName=['plot_XbyY_passDuration',prefix];
figure(); scatter(xDisp(isIT), yDisp(isIT),10,lPass(isIT),'filled')
set(gca,'xlim',[minX,maxX],'ylim',[minY,maxY]);
colormap(jet)
c=colorbar;
c.Label.String='Length of continuity';
title('Pass thresholds')
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

% X&Y with duration of IT passing threshold, but overall fail
saveName=['plot_XbyY_failDuration',prefix];
figure(); scatter(xDisp(notIT), yDisp(notIT),10,lPass(notIT),'filled')
set(gca,'xlim',[minX,maxX],'ylim',[minY,maxY]);
colormap(jet)
c=colorbar;
c.Label.String='Length of continuity';
title('Fail thresholds')
saveas(gcf, fullfile(saveDir,[saveName,'.fig']));
vectorSave(gcf, fullfile(saveDir,[saveName,'.pdf']));

close all;

end
